# Component inventory — Sudoku-rb port

Surveyed from `origin/main` (upstream PyGObject source) against the `ruby`
branch's `lib/sudoku/`. Units are ordered the way a user meets them: app
entry, main window, its pages/dialogs, then the shared game engine and
cross-cutting pieces (persistence, preferences, logging, styling,
translations).

Overall picture: **the port already covers every upstream source file.**
There are no missing `lib/*.rb` files. The items below are the mapping, with
notes on where upstream splits into several files that the port deliberately
collapses into one (the two game variants), and a couple of upstream files
whose logic is inlined into a sibling rather than given its own file.

## Entry points

| Upstream file | Port path | Kind | Exists? |
|---|---|---|---|
| `src/main.py` | `exe/sudoku` (+ `Sudoku::Application.new.build.run` in `lib/sudoku/application.rb`) | app entry point | Yes |
| `src/application.py` | `lib/sudoku/application.rb` | `Adw`/`Gtk` application class — logging setup, stylesheet install, actions/accelerators, presents main window | Yes |

## Main window and its screens

| Upstream file(s) | Port path | Kind | Exists? |
|---|---|---|---|
| `src/window.py` + `data/blueprints/window.blp` | `lib/sudoku/window.rb` | main window — header bar, stack (menu / game grid / loading / end states) | Yes |
| `src/screens/loading_screen.py` + `data/blueprints/loading-screen.blp` | `lib/sudoku/loading_screen.rb` | page — loading/startup state | Yes |
| `src/screens/finished_page.py` + `data/blueprints/finished-page.blp` | `lib/sudoku/finished_page.rb` | page — puzzle-solved state | Yes |
| `src/screens/game_over_page.py` + `data/blueprints/game-over-page.blp` | `lib/sudoku/game_over_page.rb` | page — game-over/mistakes-exceeded state | Yes |
| `src/screens/game_setup_dialog.py` | `lib/sudoku/game_setup_dialog.rb` | dialog — new game / variant & difficulty picker | Yes |
| `src/screens/help_dialog.py` + `data/blueprints/how-to-play-dialog.blp` | `lib/sudoku/help_dialog.rb` | dialog — "How to Play" | Yes |
| `src/screens/preferences_dialog.py` | `lib/sudoku/preferences_dialog.rb` | dialog — app preferences | Yes |
| `src/screens/preferences_page.py` | `lib/sudoku/preferences_page.rb` | page/widget embedded in the preferences dialog | Yes |
| `data/blueprints/shortcuts-dialog.blp` (no backing `.py` — pure Blueprint) | `lib/sudoku/shortcuts_dialog.rb` | standalone dialog — keyboard shortcuts overlay | Yes |

## Shared game-board widgets and interaction

| Upstream file | Port path | Kind | Exists? |
|---|---|---|---|
| `src/shared/grid_manager.py` | `lib/sudoku/grid_manager.rb` | widget group — the 9×9 grid of cell widgets, block/row/col CSS state | Yes |
| `src/shared/sudoku_cell.py` | `lib/sudoku/sudoku_cell.rb` | widget — one cell (button/label + CSS classes for given/selected/conflict/pencil) | Yes |
| `src/shared/input_handler.py` | `lib/sudoku/input_handler.rb` | controller logic — keyboard/pointer input routing to the grid | Yes |
| `src/shared/popover_manager.py` | `lib/sudoku/popover_manager.rb` | widget — number-pad / pencil-mark popover shown per cell | Yes |
| `src/shared/utils.py` (`schedule_feedback_clear`, `clear_cell_feedback`) | inlined into `lib/sudoku/grid_manager.rb`, `lib/sudoku/sudoku_cell.rb`, `lib/sudoku/controller.rb` | helper functions, not a widget/class — no dedicated upstream-mapped file was expected; confirmed present as inlined equivalents (CSS-feedback-clear helpers) rather than a separate `utils.rb` | Yes (inlined, not a gap) |

## Core engine (board/rules, independent of GTK)

| Upstream file | Port path | Kind | Exists? |
|---|---|---|---|
| `src/core/board.py` | `lib/sudoku/board.rb` | model — board state, cell values, validity | Yes |
| `src/core/controller.py` | `lib/sudoku/controller.rb` | model/controller — game session (moves, mistakes, pencil marks, timer) | Yes |
| `src/core/generator.py` | `lib/sudoku/generator.rb` | model — puzzle generation | Yes |
| `src/core/persistence.py` | `lib/sudoku/persistence.rb` | model — save/load board + preferences JSON under `GLib.get_user_data_dir` | Yes |
| `src/core/preferences.py` | `lib/sudoku/preferences.rb` | model — preferences manager + `_migrate_general_preferences` | Yes |
| `src/core/constants.py` (`SudokuConstants.block_size`) | inlined (`BLOCK_SIZE`/equivalent constant) into `lib/sudoku/board.rb`, `lib/sudoku/generator.rb`, `lib/sudoku/grid_manager.rb`, `lib/sudoku/controller.rb`, `lib/sudoku/sudoku_cell.rb`, `lib/sudoku/classic_sudoku.rb`, `lib/sudoku/diagonal_sudoku.rb`, `lib/sudoku/persistence.rb` | constant, not a class — confirmed inlined everywhere upstream used it, not a separate `constants.rb` | Yes (inlined, not a gap) |

## Game variants

Upstream splits each variant into 4 files (`board.py`, `controller.py`,
`generator.py`, `preferences.py`); the port deliberately collapses each
variant into one file. This is a legitimate consolidation, not a gap — verify
during parity review that all four upstream classes' behavior is represented.

| Upstream files | Port path | Kind | Exists? |
|---|---|---|---|
| `src/variants/classic_sudoku/board.py`, `controller.py`, `generator.py`, `preferences.py` | `lib/sudoku/classic_sudoku.rb` (92 lines) | variant bundle — classic 9×9 rules/board/controller/preferences | Yes (consolidated) |
| `src/variants/diagonal_sudoku/board.py`, `controller.py`, `generator.py`, `preferences.py` | `lib/sudoku/diagonal_sudoku.rb` (79 lines) | variant bundle — diagonal-sudoku rules/board/controller/preferences | Yes (consolidated) |

## Cross-cutting

| Upstream source | Port path | Kind | Exists? |
|---|---|---|---|
| `src/log_utils.py` | `lib/sudoku/log_utils.rb` | logging setup helper | Yes |
| `data/style.css` + `data/style-dark.css` | `lib/sudoku/style.rb` | stylesheet loader (light/dark CSS providers) | Yes |
| `po/*.po`, `po/sudokugame.pot`, `po/LINGUAS` | `lib/sudoku/translations.rb` | translation/gettext-domain loader | Yes |
| `data/io.github.sepehr_rs.Sudoku.gschema.xml` | — (no keys defined upstream: `<schema id="io.github.sepehr_rs.Sudoku" .../>` is empty) | GSettings schema | N/A — upstream itself keeps no settings in GSettings; preferences/state are the JSON files under `persistence.py`/`preferences.py`, already ported | Confirmed not a gap |

## Build/packaging files with no runtime component

Not components; listed for completeness since they were read during the
survey: `*.gresource.xml.in`, `*.metainfo.xml.in`, `*.desktop.in`,
`meson.build` (all levels), `*.json` manifests (`io.github.sepehr_rs.Sudoku*.json`),
`pytest.ini`, `pyrightconfig.json`, `.flake8`, `tests/*.py` (upstream's own
pytest suite — ported Ruby specs already exist under `spec/` and are tracked
by the `test-parity` skill, not this inventory).

## Summary

- Upstream `src/` + `data/blueprints/` files: 29 Python/Blueprint sources map
  to 23 `lib/sudoku/*.rb` files (the 8 variant files collapse 2:1 into
  `classic_sudoku.rb` / `diagonal_sudoku.rb`; `constants.py` and `utils.py`
  are inlined rather than given dedicated files).
- **No missing `lib/*.rb` file was found.** Every upstream user-facing
  component (window, 7 pages/dialogs, the shortcuts overlay, the grid/cell/
  input/popover widgets, both variants, persistence, preferences, logging,
  styling, translations) already has a corresponding port file.
- This survey did not verify widget-level parity inside each file (CSS
  classes, signal wiring, exact widget counts) — that is the job of the
  `component-parity` skill on a per-file basis, not this inventory.
