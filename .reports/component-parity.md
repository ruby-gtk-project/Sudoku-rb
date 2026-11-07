# Component parity — Sudoku-rb

| | |
|---|---|
| Upstream | `main` @ `2be119d` |
| Port | `ruby` @ `b0a9d76` |
| Units checked this round | 22 (of 25 `lib/sudoku/*.rb` files; `style.rb`, `log_utils.rb` and the non-census `rb.rb` are not driven) |
| Units with full four-axis parity proven | several (see below) — up from 0 last round |
| Units with real but partial coverage | most of the rest |
| Units with zero coverage of any kind | 2 (`style.rb`, `log_utils.rb`) |

## What changed since the last round

The runtime gate for this round reports `drive_ok=true, 50 checks, 0 failed,
covering 22 components`. Both drivers, and the new RSpec suite, were re-run
directly rather than trusted from the gate or from commit messages:

```
nix develop --command xvfb-run -a ruby test/drive_game.rb          # DRIVE OK, 41 "ok" lines
nix develop --command xvfb-run -a ruby test/drive_translations.rb  # DRIVE OK, 9 "ok" lines
nix develop --command xvfb-run -a rspec                            # 113 examples, 0 failures
```

41 + 9 = 50, matching the gate exactly. All three reproduce independently of
the commit messages that claimed them (`a1192eb`, `b0a9d76`) — this was not
taken on faith.

Four of the ten units the last round named as "opened-and-closed with zero
checks" or "no driver coverage of any kind" now have real assertions:

| Unit | Last round | This round |
|---|---|---|
| `preferences_dialog.rb` / `preferences_page.rb` | opened, zero checks | a switch (`casual_mode`) is flipped and `PreferencesManager` state is asserted to have changed |
| `help_dialog.rb` | opened, zero checks | first carousel page's title is read and asserted |
| `shortcuts_dialog.rb` (own render) | opened, zero checks | the built section's title is asserted after presenting |
| `application.rb` | not touched at all | the About dialog is presented and `debug_info` is asserted to name the app and the running Ruby version |
| `sudoku_cell.rb` feedback classes | asserted present, timeout never asserted | `wrong`/`conflict` classes are asserted, and `conflict feedback clears after its timeout` is a real `wait_until` on the CSS class actually being removed |
| `input_handler.rb` | zero key events dispatched | `handler.on_key_pressed` is called directly for a Ctrl+Right block jump (asserted by focus landing three columns over) and a digit fill (asserted by cell value) |
| `popover_manager.rb` | "has a grid" only | number selection fills the cell and pops the popover down (both asserted); the remaining-valid-inputs count is asserted to have 9 entries; the Clear button is clicked and asserted to both empty the notes and pop the popover down |
| `classic_sudoku.rb` / `diagonal_sudoku.rb` variant preferences | never flipped or asserted by anything | `spec/preferences_spec.rb` (ported 1:1 from upstream's `tests/test_preferences.py`) exercises `highlight_block`, `highlight_related_cells` and `highlight_diagonals` directly, including the classic-vs-diagonal default difference |

## What is still genuinely unverified

1. **`style.rb` — selectors confirmed present, rule bodies not diffed.** This
   round went further than last round's "not touched" note: every CSS class
   and id upstream's `data/style.css` + `data/style-dark.css` define
   (`.sudoku-cell-button`, `.clue-cell`, `.entry-cell`, `.note-cell-label`,
   `.corner-label`, `.highlight`, `.wrong`, `.correct`, `.conflict`,
   `.toggle-active`, `.icon-dropshadow`, `.sudoku-main-window`,
   `#sudoku-parent-grid`, `#sudoku-popover`, `large`/`compact-mode`/
   `small-mode`) is present as a selector in `lib/sudoku/style.rb`, confirmed
   by grepping both sides. The declared `sudoku-block` class that upstream
   applies but never styles is reproduced identically (applied in
   `grid_manager.rb`, styled nowhere, matching upstream's own dangling
   class). What is **not** checked, this round or last: whether each rule's
   *property values* (colors, sizes, margins) match on both sides — a
   byte-level diff of the declaration bodies was not done. No driver touches
   `style.rb` at all (it only loads a CSS provider; nothing renders pixels
   under the test harness to assert against).
2. **`log_utils.rb` — zero coverage of any kind, still.** No spec, no driver
   step, asserts that `LogUtils.logger` writes end up in `LogUtils.buffer.logs`
   or that the About dialog's `debug_info` actually includes captured log
   lines (only that `debug_info` names the app and Ruby version — not that the
   log-buffer portion of it is non-empty or correct).
3. **Popover badges, the insensitive-when-0-left state, and the Done
   button are still unclicked.** The driver now asserts the *count* of
   remaining valid inputs (9 entries) and that number selection works, but
   never asserts that a `corner-label` badge widget actually renders with
   that count over a button, never drives a number down to 0 remaining to
   check the button goes insensitive, and never clicks the "Done" button
   (only "Clear"). These three behaviours of `popover_manager.rb` remain
   present-but-unverified.
4. **RTL mirroring and the ghost-click filter in `input_handler.rb`** are
   still never exercised by any check, in either the drivers or the new
   RSpec suite. This is now on the same footing as upstream, though: upstream's
   own `tests/test_input_handler.py` (ported 1:1 into
   `spec/input_handler_spec.rb`, confirmed line-for-line below) also never
   tests RTL direction or the ghost-click guard — so this is a pre-existing
   upstream test gap the port faithfully inherited, not a new port-side
   regression. It is still unverified, just no longer unverified *relative to
   upstream*.
5. **`finished_page.rb`'s dark/light illustration swap** is still not driven
   (no theme change is triggered in either driver).
6. **`game_setup_dialog.rb`'s own Start-button click path.** The driver still
   calls `window.on_game_setup_selected` directly in the two full-game
   scenarios rather than clicking the dialog's "Start Game" button and letting
   its own `clicked` handler close the dialog and invoke the callback — the
   dialog's default-selection check is real, but its confirm/close wiring is
   bypassed exactly as noted last round.

## Test-suite axis closes a large part of the gap directly

`spec/*_spec.rb` (113 examples, 113 upstream `def test_*`, confirmed 1:1 per
file in `.reports/test-parity.md`) now gives `board.rb`, `generator.rb`,
`preferences.rb`, `input_handler.rb`'s non-pointer paths, and both variants'
serialization real line-by-line behavioural coverage that neither driver ever
attempted. This closes most of what the last round flagged under "variant
preference toggles never flipped" and substantially narrows the
`input_handler.rb` gap (digit/arrow/backspace/delete/enter paths are now
spec-covered; only RTL and the pointer ghost-click guard remain unexercised,
per point 4 above).

## One bug from last round, confirmed fixed

`help_dialog.rb`'s two multi-line `_()` calls (the only two of twelve
How-To-Play strings missing from `po/sudokugame.pot`) were rewritten as
single-line literals in `a1192eb`. Re-verified this round: both strings now
appear in `po/sudokugame.pot` and in all five `.po` files (`de`, `fa`, `nl`,
`vi`, `zh`) — see `.reports/translation-parity.md`.

## Verdict

Not clean, but materially improved and specifically improved rather than
generically reassured: 4 previously-zero-assertion dialogs now have a real
check each, the cell-feedback timeout and a slice of the keyboard path are
now actually driven, and the unit-test suite closes most of the
board/generator/preferences/input-handler behavioural gap outright. What
remains unverified is narrower and named above: `style.rb`'s rule bodies,
`log_utils.rb` entirely, three specific popover behaviours (badges,
insensitive-at-0, Done button), RTL/ghost-click in the keyboard handler (an
upstream-inherited gap, not a new one), the dark/light illustration swap, and
the New Game dialog's own button-click path.
