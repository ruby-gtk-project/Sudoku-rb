# frozen_string_literal: true

require_relative "sudoku/application"

# Sudoku, ported from the PyGObject application at
# github.com/sepehr-rs/sudoku. One upstream source file maps to one file under
# lib/sudoku, and each class names the file it came from.
module Sudoku
  DATA_DIR = File.expand_path("../data", __dir__)

  # The path of one of the app's own data files — the illustrations the help
  # and end-of-game pages show, and the icon directory the icon theme is
  # pointed at. Upstream reaches these through its gresource bundle.
  def self.data_path(*parts) = File.join(DATA_DIR, *parts)
end
