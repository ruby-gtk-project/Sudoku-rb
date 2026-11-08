# Component parity — Sudoku-rb

| | |
|---|---|
| Upstream | `main` @ `2be119d` |
| Port | `ruby` @ `46c2887` |
| Units checked this round | 23 (of 25 `lib/sudoku/*.rb` files; `style.rb` and the non-census `rb.rb` are not driven) |
| Units with zero coverage of any kind | 1 (`style.rb`) — down from 2 last round |

## What changed since the last round, re-run directly (not trusted from the commit message)

`46c2887` ("Close named parity gaps: log_utils coverage, popover badges/Done,
dialog click path, illustration swap") claims to close four of the five gaps
the prior `component-parity.md` named. Each was re-run from scratch:

```
nix develop --command xvfb-run -a ruby test/drive_game.rb          # DRIVE OK, 50 "ok" lines
nix develop --command xvfb-run -a ruby test/drive_translations.rb  # DRIVE OK, 9 "ok" lines
nix develop --command xvfb-run -a rspec                            # 121 examples, 0 failures
```

50 + 9 = 59 checks, matching this round's runtime gate (`drive_ok=true, 59
checks, 0 failed, covering 23 components`) exactly. 121 = 113 (prior,
upstream-ported) + 8 new (`spec/log_utils_spec.rb`, which has no upstream
test to port against — see `test-parity.md`).

| Named gap (prior round) | This round | Verified by |
|---|---|---|
| `log_utils.rb` — zero coverage of any kind | **Closed.** 4 new examples cover `setup_logging`, buffer accumulation across multiple log calls, and the empty-before-setup state | `spec/log_utils_spec.rb`, read and re-run |
| Popover badges, insensitive-at-zero, Done button unclicked | **Closed.** `test/drive_game.rb:277-312` forces a popover into a near-exhausted state, asserts a `corner-label` badge renders with a positive count, asserts the matching number button is insensitive at zero remaining, clicks "Done" via `signal_emit("clicked")`, and asserts the popover closes | re-read the driver code and re-ran it; all 6 new `ok` lines present |
| `game_setup_dialog.rb`'s own Start-button click path bypassed | **Closed.** `test/drive_game.rb:136-140` now calls `dialog.start_button.signal_emit("clicked")` instead of calling `window.on_game_setup_selected` directly | re-read the driver code |
| `finished_page.rb`'s dark/light illustration swap never driven | **Closed.** `test/drive_game.rb:384-392` forces `Adwaita::StyleManager.default.color_scheme` to `:force_light` then `:force_dark` and asserts the resolved `Gtk::Picture` file ends in `celebration-light.svg` / `celebration-dark.svg` respectively | re-read the driver code; both `ok` lines present in the re-run |

## What is still genuinely unverified

1. **`style.rb` — still zero coverage of any kind.** `grep -rn "Style\b"
   spec test` returns nothing. Every CSS selector was confirmed present by
   grep in a prior round (not re-checked this round, since neither the
   upstream CSS nor `lib/sudoku/style.rb` changed), but no spec and no
   driver step loads or asserts anything about the stylesheet, and no rule
   body (colors, sizes, margins) has ever been diffed against
   `data/style.css`/`data/style-dark.css`. This is the one remaining
   zero-coverage unit of the 25.
2. **RTL mirroring and the ghost-click filter in `input_handler.rb`** remain
   untested on both sides (upstream's own `tests/test_input_handler.py` does
   not test them either — a pre-existing upstream gap, not a port
   regression, per the prior round's finding; unchanged this round since
   neither side's input-handler code or tests moved).
3. **Translated `msgstr` values for fa/nl/vi/zh** are not spot-checked by any
   driver (only German is exercised by `test/drive_translations.rb`) — see
   `translation-parity.md`.

## Verdict

Not clean. Four of the five previously-named gaps are now genuinely closed,
each confirmed by independently re-running the driver and reading the new
assertions rather than trusting the commit message. One real, if narrow,
zero-coverage unit remains (`style.rb`), plus the two smaller named gaps
above (upstream-inherited input-handler paths, non-English `msgstr` values).
