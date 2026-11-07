# frozen_string_literal: true

# Ported from upstream tests/test_generator_contract.py.
#
# Upstream delegates puzzle construction to the `sudoku` PyPI package and the
# contract test mocks `PuzzleGenerator.make_puzzle` to check the shape of
# `_generate_impl`'s result and which `sudoku_cls` it is handed. The port has
# no such dependency to mock — `lib/sudoku/generator.rb`'s `GridSolver` builds
# puzzles itself — so this keeps the upstream test names and their
# "two 9x9 lists" shape assertion, and replaces the `sudoku_cls` kwarg check
# with the port's equivalent seam: which `extra_units` the variant's
# generator enforces (empty for Classic, the two diagonals for Diagonal).

RSpec.describe "generator contract" do
  # Ported from TestClassicGenerator.
  describe Sudoku::ClassicSudokuGenerator do
    let(:generator) { described_class.new }

    it "test_returns_tuple_of_two_9x9_lists" do
      puzzle, solution = generator.generate_impl(0.5)

      expect(puzzle).to be_a(Array)
      expect(solution).to be_a(Array)
      expect(puzzle.length).to eq(9)
      expect(puzzle).to all(have_attributes(length: 9))
      expect(solution.length).to eq(9)
      expect(solution).to all(have_attributes(length: 9))
    end

    it "test_passes_classic_sudoku_cls" do
      # No `sudoku_cls` kwarg exists in the port; the equivalent contract is
      # that Classic Sudoku constrains nothing beyond rows/columns/blocks.
      expect(generator.extra_units).to eq([])
    end
  end

  # Ported from TestDiagonalGenerator.
  describe Sudoku::DiagonalSudokuGenerator do
    let(:generator) { described_class.new }

    it "test_returns_tuple_of_two_9x9_lists" do
      puzzle, solution = generator.generate_impl(0.5)

      expect(puzzle.length).to eq(9)
      expect(solution.length).to eq(9)
    end

    it "test_passes_diagonal_sudoku_cls" do
      # The equivalent contract: Diagonal Sudoku's generator enforces the two
      # main diagonals as extra units, which Classic's does not.
      units = generator.extra_units
      expect(units.length).to eq(2)
      expect(units[0]).to eq((0...9).map { |i| [i, i] })
      expect(units[1]).to eq((0...9).map { |i| [i, 8 - i] })
    end
  end
end
