# frozen_string_literal: true

# Ported from upstream tests/conftest.py's `make_board_state` helper.
#
# Upstream bypasses GTK by swapping in a FakeCell and calling
# `object.__new__` on the board class. The Ruby port's GTK bindings load and
# construct fine headlessly under Xvfb (confirmed directly), so this builds a
# board the same way upstream's real code does — through `.new` — rather than
# reimplementing a fake cell.
module BoardStateHelper
  def make_board_state(board_class, puzzle:, solution:, block_size: 3)
    board_class.new(
      generator:        nil,
      puzzle:           puzzle,
      solution:         solution,
      difficulty:       0.5,
      difficulty_label: "Medium",
      variant:          "classic",
      block_size:       block_size,
    )
  end
end

RSpec.configure do |config|
  config.include(BoardStateHelper)

  # Ported from upstream tests/conftest.py's `_prefs_guard` fixture: every
  # example starts and ends with no live preferences, so one test's
  # PreferencesManager state cannot leak into the next.
  config.around do |example|
    Sudoku::PreferencesManager.set_preferences(nil)
    example.run
    Sudoku::PreferencesManager.set_preferences(nil)
  end
end
