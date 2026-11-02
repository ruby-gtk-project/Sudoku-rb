# frozen_string_literal: true

require_relative "classic_sudoku"

module Sudoku
  # Ported from upstream src/variants/diagonal_sudoku/board.py.
  #
  # Classic Sudoku plus the two main diagonals, which must also hold distinct
  # numbers.
  class DiagonalSudokuBoard < ClassicSudokuBoard
    def has_conflict(row, col, value)
      super.tap do |conflicts|
        already = conflicts.to_set
        diagonal_cells(row, col).each do |(r, c)|
          unless already.include?([r, c]) || (r == row && c == col)
            if value_at(r, c) == value
              conflicts << [r, c]
            end
          end
        end
      end
    end

    private

      # The diagonals that run through (row, col) — none, unless the cell is on
      # one of them.
      def diagonal_cells(row, col)
        [].tap do |cells|
          if row == col
            @size.times { |i| cells << [i, i] }
          end
          if row + col == @size - 1
            @size.times { |i| cells << [i, @size - 1 - i] }
          end
        end
      end
  end

  # Ported from upstream src/variants/diagonal_sudoku/generator.py.
  #
  # The two diagonals join rows, columns and blocks as units the generator's
  # engine enforces, so a generated puzzle is solvable under the variant's
  # rules.
  class DiagonalSudokuGenerator < ClassicSudokuGenerator
    def extra_units
      [
        size.times.map { |i| [i, i] },
        size.times.map { |i| [i, size - 1 - i] },
      ]
    end
  end

  # Ported from upstream src/variants/diagonal_sudoku/preferences.py.
  class DiagonalSudokuPreferences < ClassicSudokuPreferences
    VARIANT_DEFAULTS = ClassicSudokuPreferences::VARIANT_DEFAULTS
      .merge("highlight_diagonals" => true)
      .freeze

    def initialize
      super
      @name = "Diagonal Sudoku"
      @variant_key = "diagonal"
    end
  end

  # Ported from upstream src/variants/diagonal_sudoku/controller.py.
  class DiagonalSudokuController < CoreSudokuController
    def initialize(window)
      super(
        window,
        board_class: DiagonalSudokuBoard,
        generator:   DiagonalSudokuGenerator.new,
        board_size:  9,
        block_size:  3,
      )
    end
  end
end
