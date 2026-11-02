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
  .step("open the new game dialog") do
    Sudoku::GameSetupDialog.new(->(variant, difficulty) { [variant, difficulty] }).tap do |dialog|
      dialog.present(window)
      driver.check("dialog defaults to classic/easy", dialog.selected_variant == "classic")
      dialog.close
    end
  end
  .step("start a classic easy game") do
    window.on_game_setup_selected("classic", Sudoku::GameSetupDialog::EASY_DIFFICULTY)
    driver.check("loading screen showing", window.stack.visible_child == window.loading_screen)
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
    window.controller.pencil_mode = true
    window.controller.fill_cell(row, col, "7")
    driver.check("note recorded", window.controller.board.get_notes(row, col).include?("7"))
    window.controller.pencil_mode = false
  end
  .step("auto pencil marks") do
    window.on_auto_pencil_marks
    marked = window.controller.board.notes.flatten.count { |notes| !notes.empty? }
    driver.check("notes filled in", marked.positive?)
  end
  .step("open a cell popover") do
    row, col = first_blank.call
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
  .step("open the preferences dialog") do
    window.on_show_preferences
  end
  .step("open the how to play dialog") do
    Sudoku::HowToPlayDialog.new.tap do |dialog|
      dialog.present(window)
      dialog.close
    end
  end
  .step("open the shortcuts dialog") do
    Sudoku::ShortcutsDialog.build.tap do |dialog|
      dialog.present(window)
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
