# frozen_string_literal: true

# Drives the app under each translated locale the catalogue ships and checks
# that po/ reaches the widgets: the labels and tooltips the window builds,
# the contextual titles of the shortcuts dialog, and the English fallback for
# a message no translator has taken yet.
#
#   nix develop --command xvfb-run -a ruby test/drive_translations.rb
#
# Each locale is driven in its own subprocess, one language per invocation,
# because the translated strings are read into constants the moment the app
# is required — a second `require "sudoku"` in the same process would just
# return the first locale's already-built constants. The parent process picks
# this up from ARGV: no argument drives every language in LANGUAGES and
# reports their combined result; one argument drives that language alone,
# which is how each child invokes itself.

require "English"
require "fileutils"
require "tmpdir"

# Every German string de.po carries is checked against po/de.po directly; the
# other four languages were added to close a gap named across three
# consecutive parity-report rounds: translated msgstr values for fa, nl, vi
# and zh were never spot-checked by any automated step. Each entry below was
# read directly out of the corresponding po/<lang>.po.
LANGUAGES = {
  "de" => {
    continue:        "Spiel Fortsetzen",
    new_game:        "Neues Spiel",
    home_tooltip:    "Zurück zum Hauptmenü",
    pencil_tooltip:  "Bleistiftmodus umschalten",
    easy:            "Leicht",
    shortcut_game:   "Spiel",
  },
  "fa" => {
    continue:        "ادامه بازی",
    new_game:        "بازی جدید",
    home_tooltip:    "بازگشت به فهرست اصلی",
    pencil_tooltip:  "فعال/غیرفعال سازی حالت مداد",
    easy:            "آسان",
    shortcut_game:   "بازی",
  },
  "nl" => {
    continue:        "Spel voortzetten",
    new_game:        "Nieuw spel",
    home_tooltip:    "Terug naar hoofdmenu",
    pencil_tooltip:  "Potloodmodus in-/uitschakelen",
    easy:            "Makkelijk",
    shortcut_game:   "Spel",
  },
  "vi" => {
    continue:        "Tiếp tục trò chơi",
    new_game:        "Trò chơi mới",
    home_tooltip:    "Quay lại menu chính",
    pencil_tooltip:  "Chuyển đổi chế độ bút chì",
    easy:            "Dễ",
    shortcut_game:   "Trò chơi",
  },
  "zh" => {
    continue:        "继续游戏",
    new_game:        "新游戏",
    home_tooltip:    "返回至主菜单",
    pencil_tooltip:  "切换候选模式",
    easy:            "简单",
    shortcut_game:   "游戏",
  },
}.freeze

def run_one_language(lang)
  expected = LANGUAGES.fetch(lang)

  ENV["XDG_DATA_HOME"] = Dir.mktmpdir("sudoku-drive")
  ["LC_ALL", "LC_MESSAGES", "LANG"].each { |name| ENV.delete(name) }
  ENV["LANGUAGE"] = lang

  $LOAD_PATH.unshift(File.expand_path("../lib", __dir__))
  require "sudoku"

  checks = ->(window) do
    [
      ["catalogue loaded", Sudoku::Translations.language, lang],
      ["main menu button", window.continue_button.label, expected[:continue]],
      ["new game button", window.new_game_button.label, expected[:new_game]],
      ["home button tooltip", window.home_button.tooltip_text, expected[:home_tooltip]],
      ["pencil button tooltip", window.pencil_toggle_button.tooltip_text, expected[:pencil_tooltip]],
      ["difficulty label", Sudoku::SudokuWindow::DIFFICULTY_LABELS.fetch(0.2), expected[:easy]],
      ["dialog difficulty row", Sudoku::GameSetupDialog::DIFFICULTIES.first.first, expected[:easy]],
      [
        "shortcut section in context",
        Sudoku::ShortcutsDialog::SECTIONS.first.first,
        expected[:shortcut_game],
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
      checks.call(application.window).each do |(name, actual, exp)|
        if actual == exp
          puts "ok   [#{lang}] #{name}: #{actual}"
        else
          puts "FAIL [#{lang}] #{name}: #{actual.inspect} != #{exp.inspect}"
          failures << "#{lang}:#{name}"
        end
      end
      application.app.quit
      false
    end
  end
  application.run

  FileUtils.remove_entry(ENV["XDG_DATA_HOME"])

  failures
end

if ARGV.first
  failures = run_one_language(ARGV.first)
  if failures.empty?
    puts "DRIVE OK"
    exit(0)
  else
    puts "DRIVE FAILED: #{failures.join(', ')}"
    exit(1)
  end
else
  ruby = RbConfig.ruby
  script = __FILE__
  all_failures = []
  LANGUAGES.each_key do |lang|
    output = IO.popen([ruby, script, lang], &:read)
    puts output
    all_failures << lang unless $CHILD_STATUS.success?
  end

  if all_failures.empty?
    puts "DRIVE OK"
  else
    puts "DRIVE FAILED: #{all_failures.join(', ')}"
    exit(1)
  end
end
