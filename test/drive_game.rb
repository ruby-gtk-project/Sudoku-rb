# frozen_string_literal: true

# Drives the app through a whole game without a user: starts a classic game,
# fills the grid, exercises pencil mode, the popover and every dialog, then
# checks the save round-trips and the end-of-game pages come up.
#
#   nix develop --command xvfb-run -a ruby test/drive_game.rb

require "fileutils"
require "tmpdir"

ENV["XDG_DATA_HOME"] = Dir.mktmpdir("sudoku-drive")

$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))
require "sudoku"

# Runs a list of steps on the main loop, one per tick, and reports each one.
# A wait step is re-queued until its condition holds, so the loop keeps running
# while the generator's worker finishes.
class Driver
  TICK = 150

  def initialize(application)
    @application = application
    @steps = []
    @failures = []
  end

  def step(name, &action)
    @steps << [:step, name, action]
    self
  end

  def wait_until(name, attempts: 200, &condition)
    @steps << [:wait, name, condition, attempts]
    self
  end

  def check(name, value)
    if value
      puts "ok   #{name}"
    else
      puts "FAIL #{name}"
      @failures << name
    end
  end

  def run
    @application.build
    @application.app.signal_connect("activate") { schedule }
    @application.run
    report
  end

  private

    def schedule
      GLib::Timeout.add(TICK) { advance }
    end

    def advance
      entry = @steps.shift
      if entry.nil?
        @application.app.quit
      elsif entry[0] == :wait
        run_wait(entry)
      else
        run_step(entry)
      end
      false
    end

    def run_step(entry)
      _, name, action = entry
      begin
        action.call
        puts "--   #{name}"
      rescue StandardError => error
        puts "FAIL #{name}: #{error.class}: #{error.message}"
        @failures << name
      end
      schedule
    end

    def run_wait(entry)
      _, name, condition, attempts = entry
      if condition.call
        puts "ok   #{name}"
      elsif attempts.positive?
        @steps.unshift([:wait, name, condition, attempts - 1])
      else
        puts "FAIL #{name} (timed out)"
        @failures << name
      end
      schedule
    end

    def report
      if @failures.empty?
        puts "DRIVE OK"
      else
        puts "DRIVE FAILED: #{@failures.join(', ')}"
        exit(1)
      end
    end
end

application = Sudoku::Application.new
window = nil
driver = Driver.new(application)

# Every widget in a subtree, depth-first, regardless of how the container
# lays its children out (Gtk::Grid, Gtk::Overlay, Gtk::Box, ...).
descendants = lambda do |widget, &visit|
  child = widget.first_child
  while child
    visit.call(child)
    descendants.call(child, &visit)
    child = child.next_sibling
  end
end

# The first cell that is neither a clue nor already filled in.
first_blank = lambda do
  board = window.controller.board
  board.size.times.flat_map { |r| board.size.times.map { |c| [r, c] } }
    .find { |(r, c)| board.puzzle[r][c].nil? && board.user_inputs[r][c].nil? }
end

driver
  .step("present window") do
    window = application.window
    driver.check("main menu showing", window.stack.visible_child == window.main_menu_box)
    driver.check("new game button there", !window.new_game_button.nil?)
  end
  .step("open the new game dialog and start via its own Start Game button") do
    Sudoku::GameSetupDialog.new(window.method(:on_game_setup_selected)).tap do |dialog|
      dialog.present(window)
      driver.check("dialog defaults to classic/easy", dialog.selected_variant == "classic")
      dialog.start_button.signal_emit("clicked")
      driver.check("loading screen showing", window.stack.visible_child == window.loading_screen)
    end
  end
  .wait_until("classic puzzle generated") { window.stack.visible_child == window.game_scrolled_window }
  .step("grid is up") do
    driver.check("game page showing", window.stack.visible_child == window.game_scrolled_window)
    driver.check("board built", !window.controller.board.nil?)
    driver.check("81 cells", window.controller.grid_manager.cells.flatten.length == 81)
  end
  .step("fill one cell correctly") do
    row, col = first_blank.call
    board = window.controller.board
    window.controller.fill_cell(row, col, board.get_correct_value(row, col).to_s)
    cell = window.controller.grid_manager.cells[row][col]
    driver.check("cell took the value", cell.value == board.get_correct_value(row, col))
    driver.check("correct entry locked", !cell.editable?)
    driver.check("entry saved to disk", Sudoku::Persistence.saved_game?)
  end
  .step("make a pencil note") do
    row, col = first_blank.call
    note_cell = [row, col]
    window.controller.pencil_mode = true
    window.controller.fill_cell(row, col, "7")
    driver.check("note recorded", window.controller.board.get_notes(row, col).include?("7"))
    window.controller.pencil_mode = false
  end
  .step("wrong entry marks itself, and a duplicate flags a conflict") do
    board = window.controller.board
    blanks = board.size.times.flat_map { |r| board.size.times.map { |c| [r, c] } }
      .select { |(r, c)| board.puzzle[r][c].nil? && board.user_inputs[r][c].nil? }
    row, col = blanks.first
    same_block = lambda do |(r, c)|
      r / board.block_size == row / board.block_size && c / board.block_size == col / board.block_size
    end
    other = blanks.drop(1).find { |(r, c)| r == row || c == col || same_block.call([r, c]) }
    dupe_row, dupe_col = other
    # Avoid either cell's own correct answer, so the second fill cannot
    # accidentally land on handle_correct_input instead of a conflict.
    wrong_value = ((1..9).to_a -
      [board.get_correct_value(row, col), board.get_correct_value(dupe_row, dupe_col)]).first
    window.controller.fill_cell(row, col, wrong_value.to_s)
    wrong_cell = window.controller.grid_manager.cells[row][col]
    driver.check("wrong entry marked", wrong_cell.has_css_class?("wrong"))

    # A cell holding the same number in a shared row/column/block is now a
    # conflict — the Ruby port matches upstream: handle_wrong_input /
    # _handle_wrong_input only ever auto-clear the "conflict" class on the
    # cells they flag, never the "wrong" class on the cell itself (that is
    # cleared on the next edit).
    window.controller.fill_cell(dupe_row, dupe_col, wrong_value.to_s)
    driver.check("duplicate entry flagged the first cell as a conflict", wrong_cell.has_css_class?("conflict"))
    @conflict_cell = wrong_cell
  end
  .wait_until("conflict feedback clears after its timeout", attempts: 40) do
    @conflict_cell && !@conflict_cell.has_css_class?("conflict")
  end
  .step("ctrl+arrow moves focus by a block, digit key fills via the keyboard") do
    board = window.controller.board
    size = board.size
    # Needs a blank cell three columns from either edge, so the Ctrl+arrow
    # jump is guaranteed to land inside the board rather than being dropped
    # as out-of-bounds (which would leave the focus right where it started).
    blanks = size.times.flat_map { |r| size.times.map { |c| [r, c] } }
      .select { |(r, c)| board.puzzle[r][c].nil? && board.user_inputs[r][c].nil? }
    row, col = blanks.find { |(_, c)| c <= size - 4 } || blanks.find { |(_, c)| c >= 3 }
    keyval, target_col =
      if col <= size - 4
        [Gdk::Keyval::KEY_Right, col + 3]
      else
        [Gdk::Keyval::KEY_Left, col - 3]
      end
    window.controller.grid_manager.cells[row][col].grab_focus
    handler = window.controller.input_handler
    handler.on_key_pressed(keyval, Gdk::ModifierType::CONTROL_MASK, row, col)
    moved_cell = window.controller.grid_manager.cells[row][target_col]
    driver.check("ctrl+arrow moved focus three columns", window.focus == moved_cell)
    key_row, key_col = first_blank.call
    window.controller.grid_manager.cells[key_row][key_col].grab_focus
    correct = window.controller.board.get_correct_value(key_row, key_col)
    keyval = Gdk::Keyval.const_get("KEY_#{correct}")
    handler.on_key_pressed(keyval, Gdk::ModifierType::new(0), key_row, key_col)
    filled_cell = window.controller.grid_manager.cells[key_row][key_col]
    driver.check("digit keypress filled the focused cell", filled_cell.value == correct)
  end
  .step("auto pencil marks") do
    window.on_auto_pencil_marks
    marked = window.controller.board.notes.flatten.count { |notes| !notes.empty? }
    driver.check("notes filled in", marked.positive?)
  end
  .step("open a cell popover") do
    row, col = first_blank.call
    @popover_cell_coords = [row, col]
    window.controller.on_cell_click(
      row,
      col,
      1,
      1,
    )
  end
  .step("popover is up") do
    driver.check("popover manager has a grid", !window.controller.popover_manager.parent_grid.nil?)
  end
  .wait_until("popover widget becomes visible", attempts: 20) do
    window.controller.popover_manager.get_or_create_popover.visible?
  end
  .step("popover shows per-number remaining counts and fills on selection") do
    row, col = @popover_cell_coords
    cell = window.controller.grid_manager.cells[row][col]
    board = window.controller.board
    popover = window.controller.popover_manager.get_or_create_popover
    remaining = board.get_remaining_valid_inputs
    driver.check("remaining valid inputs is a 9-entry count", remaining.size == 9)
    correct = board.get_correct_value(row, col)
    window.controller.popover_manager.on_number_selected(correct.to_s, cell, popover, 1)
    driver.check("popover number selection filled the cell", cell.value == correct)
    driver.check("popover popped down on a left-click selection", !popover.visible?)
  end
  .step("popover Clear button clears a pencilled cell") do
    row, col = first_blank.call
    cell = window.controller.grid_manager.cells[row][col]
    board = window.controller.board
    # Auto pencil marks (a prior step) may have already toggled "4" on for
    # this cell; fill_cell's note path toggles, so start from a known-empty
    # set of notes rather than assume the toggle adds.
    board.notes[row][col].clear
    cell.update_notes(board.get_notes(row, col))
    window.controller.pencil_mode = true
    window.controller.fill_cell(row, col, "4")
    driver.check("note present before clearing", board.get_notes(row, col).include?("4"))
    window.controller.pencil_mode = false
    window.controller.on_cell_click(row, col, 1, 1)
    popover = window.controller.popover_manager.get_or_create_popover
    window.controller.popover_manager.on_clear_selected(cell, popover)
    driver.check("Clear button emptied the notes", window.controller.board.get_notes(row, col).empty?)
    driver.check("Clear button popped the popover down", !popover.visible?)
  end
  .step("popover shows remaining-count badges and goes insensitive at zero, Done closes it") do
    row, col = first_blank.call
    cell = window.controller.grid_manager.cells[row][col]
    board = window.controller.board
    forced_remaining = board.get_remaining_valid_inputs.merge(1 => 0)
    preferences = Sudoku::PreferencesManager.get_preferences
    preferences.general_toggles["show_remaining_valid_inputs"]["value"] = true
    window.controller.popover_manager.show_popover(cell, forced_remaining, Sudoku::PopoverManager::RIGHT_BUTTON)
    driver.check("popover with forced counts becomes visible", true)
  end
  .wait_until("forced-count popover widget becomes visible", attempts: 20) do
    window.controller.popover_manager.get_or_create_popover.visible?
  end
  .step("inspect the popover's number grid for badges, the zero-count button, and Done") do
    popover = window.controller.popover_manager.get_or_create_popover
    buttons = []
    labels = []
    descendants.call(popover.child) do |widget|
      if widget.is_a?(Gtk::Button)
        buttons << widget
      elsif widget.is_a?(Gtk::Label)
        labels << widget
      end
    end
    button_one = buttons.find { |button| button.label == "1" }
    driver.check("number 1 button exists and is insensitive at zero remaining", button_one && !button_one.sensitive?)
    badge_labels = labels.select { |label| label.has_css_class?("corner-label") }
    driver.check("at least one corner-label badge renders over a number button", !badge_labels.empty?)
    driver.check(
      "a badge shows a positive remaining count",
      badge_labels.any? { |label| label.label.to_i.positive? },
    )
    done_button = buttons.find { |button| button.label == "Done" }
    driver.check("Done button is present for a right-click popover", !done_button.nil?)
    done_button.signal_emit("clicked")
    driver.check("Done button popped the popover down", !popover.visible?)
  end
  .step("open the preferences dialog") do
    Sudoku::PreferencesDialog.new(-> {}).tap do |dialog|
      dialog.present(window)
      switch = dialog.general_group.controls["casual_mode"]
      was_active = switch.active?
      switch.active = !was_active
      preferences = Sudoku::PreferencesManager.get_preferences
      driver.check(
        "preferences switch flips PreferencesManager state",
        preferences.general_toggles["casual_mode"]["value"] == !was_active,
      )
      dialog.close
    end
  end
  .step("open the how to play dialog") do
    Sudoku::HowToPlayDialog.new.tap do |dialog|
      dialog.present(window)
      first_page_status = dialog.carousel.get_nth_page(0).last_child
      driver.check("carousel first page title", first_page_status.title == "The Basics")
      dialog.close
    end
  end
  .step("open the shortcuts dialog") do
    groups = Sudoku::ShortcutsDialog::SECTIONS.map do |(title, items)|
      Sudoku::ShortcutsDialog.section(title, items)
    end
    Adwaita::ShortcutsDialog.new.tap do |dialog|
      groups.each { |group| dialog.add(group) }
      dialog.present(window)
      driver.check("shortcuts section title", groups.first.title == "Game")
      dialog.close
    end
  end
  .step("open the about dialog") do
    application.about_dialog.tap do |dialog|
      dialog.present(window)
      driver.check("about dialog debug info names the app", dialog.debug_info.include?("Sudoku"))
      driver.check("about dialog debug info names Ruby", dialog.debug_info.include?("Ruby #{RUBY_VERSION}"))
      dialog.close
    end
  end
  .step("narrow the window") do
    window.apply_mode(true, "compact")
    driver.check("compact class applied", window.bp_bin.has_css_class?("compact-mode"))
    window.apply_mode(false, "compact")
  end
  .step("back to the menu, then continue") do
    window.on_back_to_menu
    driver.check("menu showing", window.stack.visible_child == window.main_menu_box)
    driver.check("continue offered", window.continue_button.visible?)
    window.on_continue_clicked
  end
  .step("saved game restored") do
    driver.check("game page showing", window.stack.visible_child == window.game_scrolled_window)
    driver.check("notes survived the round trip", window.controller.board.notes.flatten.any? { |n| !n.empty? })
  end
  .step("solve the puzzle") do
    board = window.controller.board
    board.size.times do |row|
      board.size.times do |col|
        if board.puzzle[row][col].nil?
          window.controller.fill_cell(row, col, board.get_correct_value(row, col).to_s)
        end
      end
    end
  end
  .step("finished page") do
    driver.check("finished page showing", window.stack.visible_child == window.finished_page)
    driver.check("save cleared", !Sudoku::Persistence.saved_game?)
  end
  .step("finished page illustration swaps with the colour scheme") do
    manager = Adwaita::StyleManager.default
    manager.color_scheme = :force_light
    light_file = window.finished_page.picture.file.path
    driver.check("light illustration picked while forced light", light_file.end_with?("celebration-light.svg"))
    manager.color_scheme = :force_dark
    dark_file = window.finished_page.picture.file.path
    driver.check("dark illustration picked while forced dark", dark_file.end_with?("celebration-dark.svg"))
    manager.color_scheme = :default
  end
  .step("start a game to lose") do
    window.on_game_setup_selected("diagonal", Sudoku::GameSetupDialog::EASY_DIFFICULTY)
  end
  .wait_until("diagonal puzzle generated") { window.stack.visible_child == window.game_scrolled_window }
  .step("set a mistake limit of one") do
    driver.check("diagonal game page showing", window.stack.visible_child == window.game_scrolled_window)
    preferences = Sudoku::PreferencesManager.get_preferences
    preferences.general_counted["mistake_limit"]["enabled"] = true
    preferences.general_counted["mistake_limit"]["count"] = 1
  end
  .step("make two mistakes") do
    board = window.controller.board
    wrong = lambda do |row, col|
      correct = board.get_correct_value(row, col)
      ((1..9).to_a - [correct]).first
    end
    empties = board.size.times.flat_map { |r| board.size.times.map { |c| [r, c] } }
      .select { |(r, c)| board.puzzle[r][c].nil? }
    empties.first(2).each do |(row, col)|
      if window.controller.board
        window.controller.fill_cell(row, col, wrong.call(row, col).to_s)
      end
    end
  end
  .step("game over page") do
    driver.check("game over page showing", window.stack.visible_child == window.game_over_page)
  end
  .run

FileUtils.remove_entry(ENV["XDG_DATA_HOME"])
