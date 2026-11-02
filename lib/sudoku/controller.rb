# frozen_string_literal: true

require "gtk4"
require_relative "grid_manager"
require_relative "input_handler"
require_relative "log_utils"
require_relative "persistence"
require_relative "popover_manager"
require_relative "sudoku_cell"

module Sudoku
  # Ported from upstream src/core/controller.py (CoreSudokuController).
  #
  # The game's brain: it owns the board, the grid, the input handler and the
  # popover, and it is where every player action lands — filling a cell,
  # clearing one, moving the focus, toggling pencil mode. Variants subclass it
  # only to name their board, generator and sizes.
  class CoreSudokuController
    CONFLICT_DELAY = 2000
    WRONG_DELAY = 4000
    DEFAULT_MISTAKE_LIMIT = 3
    COMPACT_SPACING = [8, 2].freeze
    ROOMY_SPACING = [10, 4].freeze

    attr_reader :window, :board, :grid_manager, :popover_manager, :input_handler
    attr_accessor :pencil_mode

    def initialize(window, board_class:, generator:, board_size:, block_size:)
      @window = window
      @board_class = board_class
      @generator = generator
      @board_size = board_size
      @block_size = block_size
      @board = nil
      @pencil_mode = false
      @conflict_cells = []
      @input_handler = build_input_handler
      @popover_manager = PopoverManager.new(@input_handler)
      @grid_manager = GridManager.new
    end

    # --- Game lifecycle -----------------------------------------------------

    # Generation runs in a worker so the loading screen stays alive; the board
    # is then built back on the main loop, where the widgets belong.
    def start_game(difficulty, difficulty_label, variant)
      @window.stack.visible_child = @window.loading_screen
      LogUtils.logger.info(
        "Starting #{variant.capitalize} Sudoku game with difficulty: #{difficulty}",
      )

      Thread.new do
        begin
          puzzle, solution = @generator.generate(difficulty)
          GLib::Idle.add do
            finish_start_game(
              puzzle,
              solution,
              difficulty,
              difficulty_label,
              variant,
            )
            false
          end
        rescue StandardError => error
          # Upstream lets the worker's exception end the thread, which leaves
          # the loading screen up for good; the port sends the player back to
          # the menu instead.
          LogUtils.logger.error("Puzzle generation failed: #{error.message}")
          GLib::Idle.add do
            @window.on_back_to_menu
            false
          end
        end
      end
    end

    def load_saved_game
      @board = @board_class.load(@generator, @block_size)
      if @board
        setup_grid
        restore_game_state
        @window.stack.visible_child = @window.game_scrolled_window
        LogUtils.logger.info("Loaded saved #{@board.variant.capitalize} Sudoku game.")
        if @board.solved?
          show_puzzle_finished_dialog
        end
      else
        LogUtils.logger.error("No saved game found.")
      end
    end

    # --- Cell input ---------------------------------------------------------

    def fill_cell(row, col, value, ctrl_is_pressed = false)
      cell = @grid_manager.cells[row][col]
      if cell.editable?
        clear_conflicts
        if @pencil_mode || ctrl_is_pressed
          note_cell(
            cell,
            row,
            col,
            value,
          )
        else
          enter_value(
            cell,
            row,
            col,
            value,
          )
        end
      end
    end

    def clear_cell(row, col, clear_all = false)
      cell = @grid_manager.cells[row][col]
      if cell.editable?
        if clear_all || !@pencil_mode
          clear_everything(cell, row, col)
        else
          erase_last_note(cell, row, col)
        end
        @board.save
        highlight_related(row, col)
      end
    end

    # --- Cell click / focus -------------------------------------------------

    def on_cell_click(row, col, button, n_press)
      cell = @grid_manager.cells[row][col]
      focus_cell(row, col)

      if cell.editable? && n_press == 1
        @popover_manager.show_popover(cell, @board.get_remaining_valid_inputs, button)
      else
        cell.grab_focus
      end
    end

    def on_move(_from_row, _from_col, to_row, to_col)
      focus_cell(to_row, to_col)
    end

    def on_show_popover(row, col, button = 0)
      cell = @grid_manager.cells[row][col]
      if cell.editable?
        @popover_manager.show_popover(cell, @board.get_remaining_valid_inputs, button)
      end
    end

    def apply_auto_pencil_marks
      @board.get_auto_pencil_marks.each do |(row, col), candidates|
        @board.notes[row][col] = candidates
        @grid_manager.cells[row][col].update_notes(candidates)
      end
      @board.save
    end

    # --- Feedback -----------------------------------------------------------

    # Casual mode checks the entry against the solution; otherwise only an
    # entry that breaks a rule is flagged.
    def on_cell_filled(cell, number)
      preferences = PreferencesManager.get_preferences
      CellFeedback.clear(cell, "correct", "wrong")

      if preferences&.general("casual_mode")
        if number == @board.get_correct_value(cell.row, cell.col)
          handle_correct_input(cell)
        else
          handle_wrong_input(cell, number)
        end
      else
        conflicts = @board.has_conflict(cell.row, cell.col, number)
        unless conflicts.empty?
          handle_wrong_input(cell, number, conflicts)
        end
      end
    end

    def check_mistakes_limit?
      limit = PreferencesManager.get_preferences&.general_counted_entry("mistake_limit")
      over = limit && @board.mistakes > limit.fetch("count", DEFAULT_MISTAKE_LIMIT)
      if over
        show_puzzle_finished_dialog(@window.game_over_page)
      end
      over
    end

    # --- Pencil mode, focus, layout ----------------------------------------

    def on_pencil_toggled(button)
      @pencil_mode = button.active?
      @popover_manager.set_pencil_mode(@pencil_mode)
    end

    def on_grid_unfocus
      @grid_manager.cells.each do |row|
        row.each { |cell| cell.remove_highlight("highlight") }
      end
      clear_conflicts
    end

    # Narrow windows tighten the spacing between blocks and cells, and the
    # cells themselves shrink.
    def apply_compact_mode(compact, _mode)
      spacing = ROOMY_SPACING
      if compact
        spacing = COMPACT_SPACING
      end
      parent_spacing, block_spacing = spacing
      if @grid_manager.parent_grid
        @grid_manager.parent_grid.row_spacing = parent_spacing
        @grid_manager.parent_grid.column_spacing = parent_spacing
      end

      @grid_manager.blocks.each do |row|
        row.each do |block|
          block.row_spacing = block_spacing
          block.column_spacing = block_spacing
        end
      end

      @grid_manager.cells.each { |row| row.each { |cell| cell&.set_compact(compact) } }
      @window.expand_game_area
    end

    def update_subtitle
      entry = PreferencesManager.get_preferences&.general_counted_entry("mistake_limit")
      suffix = ""
      if entry && entry["enabled"]
        suffix = " • Mistakes: #{@board.mistakes}"
      end
      @window.update_sudoku_window_subtitle(
        "#{@board.variant.capitalize} • #{@board.difficulty_label}#{suffix}",
      )
    end

    private

      def build_input_handler
        InputHandler.new(
          on_move:         method(:on_move),
          on_fill:         method(:fill_cell),
          on_clear:        method(:clear_cell),
          on_show_popover: method(:on_show_popover),
          on_cell_click:   method(:on_cell_click),
          board_size:      -> { @board_size },
          direction:       -> { @window.direction },
        )
      end

      def setup_grid
        @grid_manager.setup(
          @window,
          @board,
          @input_handler,
          @popover_manager,
        )
        @grid_manager.build_grid
        @popover_manager.set_parent_grid(@grid_manager.parent_grid)
      end

      def finish_start_game(puzzle, solution, difficulty, difficulty_label, variant)
        @board = @board_class.new(
          generator:        @generator,
          puzzle:           puzzle,
          solution:         solution,
          difficulty:       difficulty,
          difficulty_label: difficulty_label,
          variant:          variant,
          block_size:       @block_size,
        )
        setup_grid
        @window.stack.visible_child = @window.game_scrolled_window
      end

      # A correct entry already in the save file keeps its cell locked; a wrong
      # one is shown in red and stays editable.
      def restore_game_state
        @board.size.times do |row|
          @board.size.times do |col|
            restore_cell(row, col)
          end
        end
      end

      def restore_cell(row, col)
        cell = @grid_manager.cells[row][col]
        value = @board.user_inputs[row][col]
        if value
          cell.set_value(value)
          if value == @board.get_correct_value(row, col)
            cell.editable = false
          else
            cell.highlight("wrong")
          end
        end
        notes = @board.notes[row][col]
        unless notes.empty?
          cell.update_notes(notes)
        end
      end

      # A pencil note is refused while the entry would break a rule, and the
      # offending cells pulse instead.
      def note_cell(cell, row, col, value)
        if cell.value.nil?
          conflicts = pencil_conflicts(row, col, value)
          if conflicts.empty?
            @board.toggle_note(row, col, value)
            cell.update_notes(@board.get_notes(row, col))
            @board.save
          else
            flag_conflicts(conflicts)
            cell.start_feedback_timeout(delay: CONFLICT_DELAY) { clear_conflicts }
          end
        end
      end

      def pencil_conflicts(row, col, value)
        preferences = PreferencesManager.get_preferences
        check = true
        if preferences
          check = preferences.general("prevent_conflicting_pencil_notes", default: true)
        end
        if check
          @board.has_conflict(row, col, value.to_i)
        else
          []
        end
      end

      def enter_value(cell, row, col, value)
        cell.set_value(value.to_i)
        @board.set_input(row, col, value.to_i)
        @board.save
        on_cell_filled(cell, value.to_i)

        if @board.solved?
          show_puzzle_finished_dialog
        end
      end

      def clear_everything(cell, row, col)
        @board.clear_input(row, col)
        cell.clear
        @board.notes[row][col].clear
      end

      def erase_last_note(cell, row, col)
        notes = @board.get_notes(row, col)
        unless notes.empty?
          @board.toggle_note(row, col, notes.to_a.max_by(&:to_i))
          cell.update_notes(@board.get_notes(row, col))
        end
      end

      def focus_cell(row, col)
        @grid_manager.cells[row][col].grab_focus
        highlight_related(row, col)
      end

      # An empty cell highlights its row, column, block and diagonals; a filled
      # one highlights every cell holding the same number.
      def highlight_related(row, col)
        cells = @grid_manager.cells
        clear_highlights(cells)

        preferences = PreferencesManager.get_preferences
        if preferences
          selected_value = cells[row][col].value
          if selected_value.nil?
            highlight_neighborhood(
              cells,
              row,
              col,
              preferences,
            )
          else
            highlight_matching(cells, selected_value, preferences)
          end
        end
      end

      def clear_highlights(cells)
        @board_size.times do |row|
          @board_size.times { |col| cells[row][col].remove_highlight("highlight") }
        end
      end

      def highlight_neighborhood(cells, row, col, preferences)
        if preferences.general("highlight_row")
          @board_size.times { |i| cells[row][i].highlight("highlight") }
        end
        if preferences.general("highlight_column")
          @board_size.times { |i| cells[i][col].highlight("highlight") }
        end
        if preferences.variant("highlight_block")
          highlight_block(cells, row, col)
        end
        if preferences.variant("highlight_diagonals")
          highlight_diagonals(cells, row, col)
        end
      end

      def highlight_block(cells, row, col)
        block_row = (row / @block_size) * @block_size
        block_col = (col / @block_size) * @block_size
        @block_size.times do |r|
          @block_size.times { |c| cells[block_row + r][block_col + c].highlight("highlight") }
        end
      end

      def highlight_diagonals(cells, row, col)
        if row == col
          @board_size.times { |i| cells[i][i].highlight("highlight") }
        end
        if row + col == @board_size - 1
          @board_size.times { |i| cells[i][@board_size - 1 - i].highlight("highlight") }
        end
      end

      def highlight_matching(cells, value, preferences)
        if preferences.variant("highlight_related_cells")
          @board_size.times do |row|
            @board_size.times do |col|
              if cells[row][col].value == value
                cells[row][col].highlight("highlight")
              end
            end
          end
        end
      end

      def handle_correct_input(cell)
        cell.editable = false
        cell.highlight("correct")
        cell.tooltip_text = "Correct Entry"
        cell.start_feedback_timeout do
          CellFeedback.clear(cell, "correct")
          false
        end
        auto_remove_notes(cell)
      end

      def auto_remove_notes(cell)
        preferences = PreferencesManager.get_preferences
        auto_remove = true
        if preferences
          auto_remove = preferences.general("auto_remove_notes", default: true)
        end
        if auto_remove
          @board.remove_note_from_related(cell.row, cell.col, cell.value).each do |(row, col)|
            @grid_manager.cells[row][col].update_notes(@board.get_notes(row, col))
          end
        end
      end

      def handle_wrong_input(cell, number, conflicts = nil)
        cell.highlight("wrong")
        cell.tooltip_text = "Wrong Entry"

        unless over_mistake_limit?
          @board.save
          update_subtitle
          flag_conflicts(conflicts || @board.has_conflict(cell.row, cell.col, number))
          cell.start_feedback_timeout(delay: WRONG_DELAY) { clear_conflicts }
        end
      end

      # Counts the mistake when a limit is set, and answers whether that was
      # the mistake which ended the game — in which case the board is already
      # gone and there is nothing left to flag.
      def over_mistake_limit?
        ended = false
        if count_mistake?
          @board.mistakes += 1
          ended = check_mistakes_limit?
        end
        ended
      end

      def count_mistake?
        limit = PreferencesManager.get_preferences&.general_counted_entry("mistake_limit")
        limit && limit["enabled"]
      end

      def flag_conflicts(conflicts)
        conflicts.each do |(row, col)|
          @grid_manager.cells[row][col].tap do |cell|
            cell.highlight("conflict")
            @conflict_cells << cell
          end
        end
      end

      def clear_conflicts
        @conflict_cells.each { |cell| cell.remove_highlight("conflict") }
        @conflict_cells.clear
        false
      end

      # Ends the game: the save is deleted, the grid is torn down and the
      # finished (or game over) page takes the stack.
      def show_puzzle_finished_dialog(page = nil)
        @popover_manager.invalidate
        @window.pencil_toggle_button.visible = false
        Persistence.clear_save
        @grid_manager.cells.each { |row| row.each { |cell| cell&.clear_feedback_timeout } }
        while (child = @window.grid_container.first_child)
          @window.grid_container.remove(child)
        end
        @window.stack.visible_child = page || @window.finished_page
      end
  end
end
