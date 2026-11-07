# frozen_string_literal: true

# Ported from upstream tests/test_board_conflicts.py.

BOARD_CONFLICTS_EMPTY = Array.new(9) { Array.new(9) }.freeze

BOARD_CONFLICTS_SOLUTION = [
  [1, 2, 3, 4, 5, 6, 7, 8, 9],
  [4, 5, 6, 7, 8, 9, 1, 2, 3],
  [7, 8, 9, 1, 2, 3, 4, 5, 6],
  [2, 3, 4, 5, 6, 7, 8, 9, 1],
  [5, 6, 7, 8, 9, 1, 2, 3, 4],
  [8, 9, 1, 2, 3, 4, 5, 6, 7],
  [3, 4, 5, 6, 7, 8, 9, 1, 2],
  [6, 7, 8, 9, 1, 2, 3, 4, 5],
  [9, 1, 2, 3, 4, 5, 6, 7, 8],
].freeze

RSpec.describe "board conflicts" do
  let(:classic_board) do
    make_board_state(Sudoku::ClassicSudokuBoard, puzzle: BOARD_CONFLICTS_EMPTY, solution: BOARD_CONFLICTS_SOLUTION)
  end
  let(:diagonal_board) do
    make_board_state(Sudoku::DiagonalSudokuBoard, puzzle: BOARD_CONFLICTS_EMPTY, solution: BOARD_CONFLICTS_SOLUTION)
  end

  # Ported from TestClassicConflict.
  describe Sudoku::ClassicSudokuBoard do
    it "test_no_conflict_on_empty_board" do
      expect(classic_board.has_conflict(0, 0, 5)).to eq([])
    end

    it "test_row_conflict" do
      classic_board.sudoku_cells[0][3].set_value(5)
      expect(classic_board.has_conflict(0, 7, 5)).to include([0, 3])
    end

    it "test_column_conflict" do
      classic_board.sudoku_cells[5][0].set_value(5)
      expect(classic_board.has_conflict(8, 0, 5)).to include([5, 0])
    end

    it "test_block_conflict" do
      classic_board.sudoku_cells[1][1].set_value(5)
      expect(classic_board.has_conflict(2, 2, 5)).to include([1, 1])
    end

    it "test_no_conflict_diagonal_on_classic" do
      classic_board.sudoku_cells[4][4].set_value(5)
      expect(classic_board.has_conflict(0, 0, 5)).not_to include([4, 4])
    end

    it "test_multiple_conflicts" do
      classic_board.sudoku_cells[0][3].set_value(7)
      classic_board.sudoku_cells[7][7].set_value(7)
      classic_board.sudoku_cells[1][6].set_value(7)
      conflicts = classic_board.has_conflict(0, 7, 7)
      expect(conflicts).to include([0, 3], [7, 7], [1, 6])
    end

    it "test_conflict_with_puzzle_clue" do
      puzzle = BOARD_CONFLICTS_EMPTY.map(&:dup)
      puzzle[0][3] = 7
      board = make_board_state(Sudoku::ClassicSudokuBoard, puzzle: puzzle, solution: BOARD_CONFLICTS_SOLUTION)
      expect(board.has_conflict(0, 7, 7)).to include([0, 3])
    end
  end

  # Ported from TestDiagonalConflict.
  describe Sudoku::DiagonalSudokuBoard do
    it "test_main_diagonal_conflict" do
      diagonal_board.sudoku_cells[4][4].set_value(5)
      expect(diagonal_board.has_conflict(0, 0, 5)).to include([4, 4])
    end

    it "test_anti_diagonal_conflict" do
      diagonal_board.sudoku_cells[4][4].set_value(5)
      expect(diagonal_board.has_conflict(8, 0, 5)).to include([4, 4])
    end

    it "test_diagonal_does_not_conflict_off_diagonal" do
      diagonal_board.sudoku_cells[5][3].set_value(5)
      expect(diagonal_board.has_conflict(0, 0, 5)).not_to include([5, 3])
    end

    it "test_classic_board_ignores_diagonal" do
      classic_board.sudoku_cells[4][4].set_value(5)
      expect(classic_board.has_conflict(0, 0, 5)).to eq([])
    end
  end
end
