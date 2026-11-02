# frozen_string_literal: true

require "set"
require_relative "persistence"
require_relative "sudoku_cell"

module Sudoku
  # Ported from upstream src/core/board.py (CoreSudokuBoard).
  #
  # The state of one game: the clues, the solution, the player's entries, the
  # pencil notes, the mistake count — and the cell widgets, which upstream's
  # board also owns because the grid is built from them and the solved check
  # reads their values back. Variants add the conflict and solved rules.
  class CoreSudokuBoard
    attr_reader :generator, :difficulty, :difficulty_label, :variant, :block_size
    attr_reader :puzzle, :solution, :size, :user_inputs, :notes, :sudoku_cells
    attr_reader :variant_preferences
    attr_accessor :mistakes

    def initialize(generator:, puzzle:, solution:, difficulty:, difficulty_label:, variant:, block_size:)
      @generator = generator
      @difficulty = difficulty
      @difficulty_label = difficulty_label
      @variant = variant
      @block_size = block_size
      @puzzle = puzzle
      @solution = solution
      @mistakes = 0
      @variant_preferences = Persistence.load_variant_preferences(variant)
      @size = puzzle.length
      @user_inputs = Array.new(@size) { Array.new(@size) }
      @notes = Array.new(@size) { Array.new(@size) { Set.new } }
      @sudoku_cells = initialize_sudoku_cells
    end

    def initialize_sudoku_cells
      Array.new(@size) do |row|
        Array.new(@size) do |col|
          SudokuCell.new(
            value:         @puzzle[row][col],
            correct_value: @solution[row][col],
            editable:      @puzzle[row][col].nil?,
            block_size:    @block_size,
          )
        end
      end
    end

    def clue?(row, col) = !@puzzle[row][col].nil?

    def get_correct_value(row, col) = @solution[row][col]

    def set_input(row, col, value)
      @user_inputs[row][col] = value
    end

    def get_input(row, col) = @user_inputs[row][col]

    def clear_input(row, col)
      @user_inputs[row][col] = nil
    end

    def toggle_note(row, col, value)
      note = value.to_s
      if @notes[row][col].include?(note)
        @notes[row][col].delete(note)
      else
        @notes[row][col].add(note)
      end
    end

    def get_notes(row, col) = @notes[row][col]

    # The valid candidates of every cell the player has left empty, keyed by
    # [row, col] — what "Auto Pencil Marks" fills the grid with.
    def get_auto_pencil_marks
      {}.tap do |marks|
        each_position do |row, col|
          if @puzzle[row][col].nil? && @user_inputs[row][col].nil?
            marks[[row, col]] = candidates_for(row, col)
          end
        end
      end
    end

    # Drops `value` from the notes of every cell that shares a row, column or
    # block with (row, col). Answers the positions whose notes changed, so the
    # caller can redraw just those cells.
    def remove_note_from_related(row, col, value)
      note = value.to_s
      [].tap do |affected|
        each_position do |r, c|
          unless r == row && c == col
            if related?(
              r,
              c,
              row,
              col,
            ) && @notes[r][c].include?(note)
              @notes[r][c].delete(note)
              affected << [r, c]
            end
          end
        end
      end
    end

    # How many of each number are still to be placed, counting the clues and
    # the player's correct entries. Shown in the popover's corner labels.
    def get_remaining_valid_inputs
      (1..9).to_h { |number| [number, 9] }.tap do |remaining|
        each_position do |row, col|
          clue = @puzzle[row][col]
          if clue
            remaining[clue] -= 1
          end
          entry = @user_inputs[row][col]
          if entry && entry == @solution[row][col]
            remaining[entry] -= 1
          end
        end
      end
    end

    def self.load(generator, block_size = 3)
      Persistence.load_game(self, generator: generator, block_size: block_size)
    end

    def save
      Persistence.save_game(self)
    end

    private

      def each_position
        @size.times do |row|
          @size.times { |col| yield(row, col) }
        end
      end

      def candidates_for(row, col)
        Set.new.tap do |candidates|
          (1..@size).each do |value|
            if has_conflict(row, col, value).empty?
              candidates.add(value.to_s)
            end
          end
        end
      end

      def related?(row, col, other_row, other_col)
        same_block = row / @block_size == other_row / @block_size &&
          col / @block_size == other_col / @block_size
        row == other_row || col == other_col || same_block
      end
  end
end
