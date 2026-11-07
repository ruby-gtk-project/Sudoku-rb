# Component parity — Sudoku-rb

| | |
|---|---|
| Upstream | `main` @ `2be119d` |
| Port | `ruby` @ `5ee083b` |
| Units checked this round | 20 |
| Units with full four-axis parity proven | 0 (see below) |
| Units with code present but unverified | 20 |

## What "present" does not prove

`.reports/component-inventory.md` marks all 13 UI component files and all
non-UI files as "present" (the code exists, the widget types match on
reading). That is Steps 1–3 of this skill. Steps 4 and 5 — confirm the
styling actually renders, and confirm the behaviour actually fires, by
driving the running app — are the steps that turn "present" into "has
parity", and this round ran the port's own drivers to check them.

The runtime gate for this round reports `drive_ok=true, 31 checks, 0
failed, covering 20 components`. Both drivers were re-run directly rather
than trusted from the gate:

```
nix develop --command xvfb-run -a ruby test/drive_game.rb          # DRIVE OK, 22 ok lines
nix develop --command xvfb-run -a ruby test/drive_translations.rb  # DRIVE OK, 9 ok lines
```

Both reproduce. The gap is not that the checks fail — it is that "31 checks
... covering 20 components" overstates what was checked **per component**,
per this skill's rule that a component needs all four axes (count, style,
behaviour, text) checked, not a mention in a step list. Reading
`test/drive_game.rb` line by line against its own `check(...)` calls:

| Unit | Touched by a `step` | Covered by a `check` (an actual assertion) |
|---|---|---|
| `window.rb` (menu, header, breakpoints) | yes | yes — 5 checks |
| `game_setup_dialog.rb` | yes | partial — only the default radio selection is checked, never a different variant/difficulty choice, never the Start button's actual click path (the driver calls `window.on_new_game_clicked` directly in some paths, bypassing the dialog's own confirm handler) |
| `loading_screen.rb` | yes | only "is it the visible stack child" |
| `grid_manager.rb` / `sudoku_cell.rb` | yes | cell count and one cell's value/editable state; **the feedback CSS classes (`wrong`, `correct`, `conflict`, `toggle-active`, `highlight`) and their 2000 ms/4000 ms timeout-clear are never asserted** |
| `popover_manager.rb` | yes | only "has a grid"; **the remaining-count badges, the insensitive-when-0-left state, and the Clear/Done buttons are never clicked or asserted** |
| `preferences_dialog.rb` / `preferences_page.rb` | **yes, but zero checks follow** — `window.on_show_preferences` is called and the driver moves on. No switch is toggled, no `Adw.SpinRow` value is set, no row title/subtitle is read. The whole preferences surface (8 toggle rows + 1 spin row + 2–3 variant rows) is opened and immediately abandoned by the driver. |
| `help_dialog.rb` | **yes, but zero checks follow** — `Sudoku::HowToPlayDialog.new` is presented and closed in the same step with no assertion in between. None of the six carousel pages, the dot indicator, or the prev/next buttons are driven. |
| `shortcuts_dialog.rb` | **yes, but zero checks follow** for the dialog's own presentation — `Sudoku::ShortcutsDialog.build` is presented and closed with no assertion. (Its *strings* are checked separately, by `drive_translations.rb`'s "shortcut section in context" — but that reads the `SECTIONS` constant directly, not anything the presented dialog displays.) |
| `application.rb` | **not touched at all** by either driver. `app.about`, `app.how_to_play` (as an app action rather than the direct class call the driver uses), `app.shortcuts`, the accelerator table, and `Adwaita::AboutDialog` + `generate_debug_info` are never exercised by any check in this repo. |
| `style.rb` | not touched by either driver, and not diffed against upstream's `data/style.css` / `data/style-dark.css` this round (see below) |
| `log_utils.rb` | not touched |
| `input_handler.rb` | `grid_manager`'s controllers are built (cell count check), but no key event is dispatched through either driver — arrow-key movement, Ctrl+arrow jump-by-three, digit fill, Ctrl+digit pencil mark, RTL mirroring, and the ghost-click filter are all unexercised by any automated check in the repo |
| `classic_sudoku.rb` / `diagonal_sudoku.rb` generators & preferences | only "a puzzle generated" (board non-nil) for each variant; the variant-specific preference toggles (`highlight_block`, `highlight_related_cells`, `highlight_diagonals`) are never flipped or asserted |
| `game_over_page.rb` / `finished_page.rb` | yes | yes — "page showing" only; the dark/light illustration swap on `finished_page.rb` is not driven (no theme change in the driver) |

**Finding:** of the 20 components the gate counts, 4 (preferences dialog,
help dialog, shortcuts dialog's own render, application.rb/About dialog) are
opened-and-closed with literally zero assertions in between, and a further 6
(popover badges/Done button, cell feedback classes and timeouts,
input_handler's key map, variant preference toggles, style.rb, log_utils.rb)
have no driver coverage of any kind. Per this skill's rule ("never report
parity from the scan alone... steps 4 and 5 are where the axes are actually
checked"), none of these ten have had Step 4/5 performed, so parity is
**unproven, not disproven**, for each — which is exactly the "component no
check exercises is unverified, not done" instruction this audit was asked to
apply.

## Stylesheet axis — not compared this round

`lib/sudoku/style.rb` is reported by the existing inventory as the Ruby
rendering of `data/style.css` + `data/style-dark.css`. This round did not
byte-diff the two:

```
git show origin/main:data/style.css > /tmp/up-style.css
git show origin/main:data/style-dark.css > /tmp/up-style-dark.css
```

against the Ruby heredoc/string in `lib/sudoku/style.rb` — the file was read
far enough to confirm it exists and is loaded, not far enough to confirm
every selector (`.sudoku-cell-button`, `.clue-cell`, `.entry-cell`,
`.note-cell-label`, `.corner-label`, `.highlight`, `.wrong`, `.correct`,
`.conflict`, `.toggle-active`, `#sudoku-parent-grid`, `#sudoku-popover`, and
the `large`/`compact-mode`/`small-mode` variants) carries the same rule body
on both sides. **This is a gap in the audit, not a claim that the stylesheet
is wrong** — it is named here so the next pass does not skip it believing
this pass covered it.

## One confirmed real bug, found by chasing the text axis

See `.reports/translation-parity.md` for the full account: `help_dialog.rb`
correctly wraps all six carousel-page descriptions in `_()`, but two of the
six — the ones written as multi-line string-literal concatenations — never
reach `po/sudokugame.pot`. The widget-count and CSS axes for `help_dialog.rb`
are fine; the text axis has a real, confirmed gap on two of twelve strings.

## Verdict

Not clean. Component *files* match 1:1 with upstream units (confirmed by
`component-identification`), but component *parity* — all four axes, proven
by driving the app, per component — is unproven for half the unit list, and
the translation-parity gap above is a confirmed component-level text-axis
failure on `help_dialog.rb`.
