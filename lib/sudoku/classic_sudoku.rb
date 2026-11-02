# frozen_string_literal: true

require_relative "board"
require_relative "controller"
require_relative "generator"
require_relative "preferences"

module Sudoku
  # Ported from upstream src/variants/classic_sudoku/board.py.
  #
  # The rules of ordinary Sudoku: a number may not repeat in a row, a column
  # or a block.
  class ClassicSudokuBoard < CoreSudokuBoard
    # Every clue has its solution value and every cell the player filled holds
    # it too.
    def solved?
      @sudoku_cells.each_with_index.all? do |row, r|
        row.each_with_index.all? do |cell, c|
          !@puzzle[r][c].nil? || cell.value == @solution[r][c]
        end
      end
    end

    # The cells that already hold `value` and share a unit with (row, col).
    # Clues are read from the puzzle and the player's entries from the cells,
    # which is where an entry lives until it is saved.
    def has_conflict(row, col, value)
      [].tap do |conflicts|
        @size.times do |r|
          @size.times do |c|
            unless r == row && c == col
              if shares_unit?(
                r,
                c,
                row,
                col,
              ) && value_at(r, c) == value
                conflicts << [r, c]
              end
            end
          end
        end
      end
    end

    private

      def shares_unit?(row, col, other_row, other_col)
        same_block = row / @block_size == other_row / @block_size &&
          col / @block_size == other_col / @block_size
        row == other_row || col == other_col || same_block
      end

      def value_at(row, col)
        @puzzle[row][col] || @sudoku_cells[row][col].value
      end
  end

  # Ported from upstream src/variants/classic_sudoku/generator.py.
  #
  # Rows, columns and blocks are the only constraints, which is what the core
  # engine builds puzzles against by default.
  class ClassicSudokuGenerator < CoreSudokuGenerator
  end

  # Ported from upstream src/variants/classic_sudoku/preferences.py.
  class ClassicSudokuPreferences < CoreSudokuPreferences
    VARIANT_DEFAULTS = {
      "highlight_block"         => true,
      "highlight_related_cells" => true,
    }.freeze

    def initialize
      super
      @name = "Classic Sudoku"
      @variant_key = "classic"
    end
  end

  # Ported from upstream src/variants/classic_sudoku/controller.py.
  class ClassicSudokuController < CoreSudokuController
    def initialize(window)
      super(
        window,
        board_class: ClassicSudokuBoard,
        generator:   ClassicSudokuGenerator.new,
        board_size:  9,
        block_size:  3,
      )
    end
  end
end
