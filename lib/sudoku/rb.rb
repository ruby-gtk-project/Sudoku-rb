# frozen_string_literal: true

require_relative "rb/version"
require_relative "../sudoku"

# Gem entry point named after the gemspec ("sudoku-rb" => "sudoku/rb"), kept
# separate from `Sudoku::Rb::VERSION` (lib/sudoku/rb/version.rb) so requiring
# it also loads the app itself (lib/sudoku.rb).
module Sudoku
  module Rb
  end
end
