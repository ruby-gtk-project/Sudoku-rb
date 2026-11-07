# frozen_string_literal: true

# Ported from upstream tests/test_board_core.py.

BOARD_CORE_PUZZLE = [
  [1, nil, 3, nil, 5, nil, 7, nil, 9],
  [nil, nil, nil, nil, nil, nil, nil, nil, nil],
  [nil, nil, nil, nil, nil, nil, nil, nil, nil],
  [nil, nil, nil, nil, nil, nil, nil, nil, nil],
  [nil, nil, nil, nil, nil, nil, nil, nil, nil],
  [nil, nil, nil, nil, nil, nil, nil, nil, nil],
  [nil, nil, nil, nil, nil, nil, nil, nil, nil],
  [nil, nil, nil, nil, nil, nil, nil, nil, nil],
  [nil, nil, nil, nil, nil, nil, nil, nil, nil],
].freeze

BOARD_CORE_SOLUTION = [
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

RSpec.describe Sudoku::ClassicSudokuBoard do
  let(:board) { make_board_state(described_class, puzzle: BOARD_CORE_PUZZLE, solution: BOARD_CORE_SOLUTION) }

  # Ported from TestIsClue. Upstream's `is_clue` is the port's `clue?`.
  describe "#clue?" do
    it "test_clue_returns_true" do
      expect(board.clue?(0, 0)).to be(true)
    end

    it "test_empty_returns_false" do
      expect(board.clue?(0, 1)).to be(false)
    end

    it "test_different_clue_positions" do
      expect(board.clue?(0, 2)).to be(true)
      expect(board.clue?(0, 4)).to be(true)
    end
  end

  # Ported from TestGetCorrectValue.
  describe "#get_correct_value" do
    it "test_returns_solution_value" do
      expect(board.get_correct_value(0, 1)).to eq(2)
      expect(board.get_correct_value(1, 0)).to eq(4)
    end

    it "test_clue_cell_matches_solution" do
      expect(board.get_correct_value(0, 0)).to eq(1)
    end
  end

  # Ported from TestInputAccessors.
  describe "#set_input / #get_input / #clear_input" do
    it "test_set_and_get" do
      board.set_input(1, 0, 4)
      expect(board.get_input(1, 0)).to eq(4)
    end

    it "test_get_returns_none_for_empty" do
      expect(board.get_input(1, 1)).to be_nil
    end

    it "test_clear_input" do
      board.set_input(1, 0, 4)
      board.clear_input(1, 0)
      expect(board.get_input(1, 0)).to be_nil
    end
  end

  # Ported from TestNotes.
  describe "#toggle_note / #get_notes" do
    it "test_toggle_adds_note" do
      board.toggle_note(1, 1, "5")
      expect(board.get_notes(1, 1)).to include("5")
    end

    it "test_toggle_removes_note" do
      board.toggle_note(1, 1, "5")
      board.toggle_note(1, 1, "5")
      expect(board.get_notes(1, 1)).not_to include("5")
    end

    it "test_get_notes_returns_set" do
      expect(board.get_notes(1, 1)).to be_a(Set)
    end

    it "test_multiple_notes" do
      board.toggle_note(1, 1, "3")
      board.toggle_note(1, 1, "7")
      expect(board.get_notes(1, 1)).to eq(Set.new(%w[3 7]))
    end
  end

  # Ported from TestRemoveNoteFromRelated.
  describe "#remove_note_from_related" do
    it "test_removes_from_same_row" do
      board.toggle_note(0, 3, "5")
      affected = board.remove_note_from_related(0, 0, 5)
      expect(affected).to include([0, 3])
      expect(board.get_notes(0, 3)).not_to include("5")
    end

    it "test_removes_from_same_column" do
      board.toggle_note(3, 0, "5")
      affected = board.remove_note_from_related(0, 0, 5)
      expect(affected).to include([3, 0])
    end

    it "test_removes_from_same_block" do
      board.toggle_note(1, 2, "5")
      affected = board.remove_note_from_related(0, 0, 5)
      expect(affected).to include([1, 2])
    end

    it "test_does_not_remove_unrelated" do
      board.toggle_note(5, 5, "5")
      affected = board.remove_note_from_related(0, 0, 5)
      expect(affected).not_to include([5, 5])
      expect(board.get_notes(5, 5)).to include("5")
    end

    it "test_does_not_remove_from_self" do
      board.toggle_note(0, 0, "5")
      board.remove_note_from_related(0, 0, 5)
      expect(board.get_notes(0, 0)).to include("5")
    end
  end

  # Ported from TestRemainingValidInputs.
  describe "#get_remaining_valid_inputs" do
    it "test_clue_values_decremented" do
      remaining = board.get_remaining_valid_inputs
      expect(remaining[1]).to eq(8)
      expect(remaining[3]).to eq(8)
      expect(remaining[5]).to eq(8)
      expect(remaining[7]).to eq(8)
      expect(remaining[9]).to eq(8)
    end

    it "test_non_clue_values_at_nine" do
      remaining = board.get_remaining_valid_inputs
      expect(remaining[2]).to eq(9)
      expect(remaining[4]).to eq(9)
      expect(remaining[6]).to eq(9)
      expect(remaining[8]).to eq(9)
    end

    it "test_decrements_for_correct_user_input" do
      board.set_input(1, 0, 4)
      remaining = board.get_remaining_valid_inputs
      expect(remaining[4]).to eq(8)
    end

    it "test_does_not_decrement_for_wrong_user_input" do
      board.set_input(1, 0, 9)
      remaining = board.get_remaining_valid_inputs
      expect(remaining[9]).to eq(8)
    end
  end

  # Ported from TestIsSolved. Upstream's `is_solved` is the port's `solved?`.
  describe "#solved?" do
    it "test_empty_board_not_solved" do
      expect(board.solved?).to be(false)
    end

    it "test_partially_filled_not_solved" do
      9.times { |c| board.sudoku_cells[1][c].set_value(BOARD_CORE_SOLUTION[1][c]) }
      expect(board.solved?).to be(false)
    end

    it "test_fully_correct_solved" do
      9.times do |r|
        9.times do |c|
          if BOARD_CORE_PUZZLE[r][c].nil?
            board.sudoku_cells[r][c].set_value(BOARD_CORE_SOLUTION[r][c])
          end
        end
      end
      expect(board.solved?).to be(true)
    end
  end
end
