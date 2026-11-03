# frozen_string_literal: true

# Drives the app in German and checks that the catalogue in po/ reaches the
# widgets: the labels and tooltips the window builds, the contextual titles of
# the shortcuts dialog, and the English fallback for a message no translator
# has taken yet.
#
#   nix develop --command xvfb-run -a ruby test/drive_translations.rb
#
# The locale is set here rather than on the command line because several
# classes translate their labels into constants, which are built the moment the
# app is required.

require "fileutils"
require "tmpdir"

ENV["XDG_DATA_HOME"] = Dir.mktmpdir("sudoku-drive")
["LC_ALL", "LC_MESSAGES", "LANG"].each { |name| ENV.delete(name) }
ENV["LANGUAGE"] = "de"

$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))
require "sudoku"

# The expectations, as [description, actual, expected] once the window is up.
# Every German string here is one upstream's own po/de.po carries.
def checks(window)
  [
    ["catalogue loaded", Sudoku::Translations.language, "de"],
    ["main menu button", window.continue_button.label, "Spiel Fortsetzen"],
    ["new game button", window.new_game_button.label, "Neues Spiel"],
    ["home button tooltip", window.home_button.tooltip_text, "Zurück zum Hauptmenü"],
    ["pencil button tooltip", window.pencil_toggle_button.tooltip_text, "Bleistiftmodus umschalten"],
    ["difficulty label", Sudoku::SudokuWindow::DIFFICULTY_LABELS.fetch(0.2), "Leicht"],
    ["dialog difficulty row", Sudoku::GameSetupDialog::DIFFICULTIES.first.first, "Leicht"],
    [
      "shortcut section in context",
      Sudoku::ShortcutsDialog::SECTIONS.first.first,
      "Spiel",
    ],
    [
      "untranslated message falls back",
      Sudoku::FinishedPage::VICTORY_MESSAGE,
      "Puzzle Complete!",
    ],
  ]
end

failures = []
application = Sudoku::Application.new

application.build
application.app.signal_connect("activate") do
  GLib::Timeout.add(150) do
    checks(application.window).each do |(name, actual, expected)|
      if actual == expected
        puts "ok   #{name}: #{actual}"
      else
        puts "FAIL #{name}: #{actual.inspect} != #{expected.inspect}"
        failures << name
      end
    end
    application.app.quit
    false
  end
end
application.run

FileUtils.remove_entry(ENV["XDG_DATA_HOME"])

if failures.empty?
  puts "DRIVE OK"
else
  puts "DRIVE FAILED: #{failures.join(', ')}"
  exit(1)
end
