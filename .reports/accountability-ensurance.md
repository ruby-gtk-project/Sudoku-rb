# Accountability ensurance — Sudoku-rb

| | |
|---|---|
| Upstream | `main` @ `2be119d` |
| Port | `ruby` @ `b0a9d76` |

## Grep for excuse language — re-run fresh this round

```
grep -rniE "TODO|FIXME|not implemented|for now|in a future|not yet|unimplemented|placeholder\b|stub\b|dropped deliberately|not applicable|no ruby analogue|out of scope|not needed|by design|by choice|deliberate simplification|streamlined|modernised away|bindings do not support|skipped" lib exe .reports PORTING.md AGENTS.md CLAUDE.md
```

No `PORTING.md` exists on `ruby` (still true). No hit in `lib/`, `exe/`,
`AGENTS.md`, `CLAUDE.md` is an excuse construction. Two new hits since the
last round, both read in context and both benign:

- `lib/sudoku/popover_manager.rb:135` — `LogUtils.logger.debug("Popover
  popdown skipped")`: a debug log line fired when a popdown is a no-op
  because the popover is already closed, not a comment admitting a missing
  feature.
- `lib/sudoku/sudoku_cell.rb:181` — "a redundant switch is skipped so the
  notes are not rebuilt for nothing": a performance short-circuit comment,
  not a scope cut.

The pre-existing `popover_manager.rb:151` comment ("allocation when the two
are not yet related") is unchanged and is still GTK allocation-timing prose,
not an excuse. **On the excuse-language axis, the port remains clean.**

## The false-green question, re-asked against this round's own evidence rather than against commit messages

Every claim in this round's four companion reports was independently
re-executed rather than taken from a commit message or a prior report:

- `nix develop --command xvfb-run -a ruby test/drive_game.rb` → `DRIVE OK`,
  41 `ok` lines, re-run directly, not copied from `b0a9d76`'s commit message.
- `nix develop --command xvfb-run -a ruby test/drive_translations.rb` →
  `DRIVE OK`, 9 `ok` lines, re-run directly.
- `nix develop --command xvfb-run -a rspec` → `113 examples, 0 failures`,
  re-run directly. Last round this command (then written slightly
  differently in the devshell banner) failed at `require "kettle/test/
  rspec"` before collecting a single example — that failure is gone, and the
  banner itself now prints `run the specs: xvfb-run rspec` rather than the
  longer `ruby -e '...'` form the old banner used, confirming the devshell
  itself changed, not just the test files.
- The two previously-missing po msgids were grepped directly out of
  `po/sudokugame.pot` and all five `.po` files, not inferred from the "fixed"
  commit message.
- The 113-vs-113 test census was counted from `git show origin/main:tests/
  *.py` and `spec/*_spec.rb` directly, file by file, not accepted as a round
  number.

41 + 9 = 50, matching the runtime gate's "50 checks ... covering 22
components" exactly, and 22 of the port's 25 `lib/sudoku/*.rb` files are
genuinely touched by one of those three test entry points (confirmed in
`.reports/component-parity.md`) — `style.rb`, `log_utils.rb`, and the
non-census `rb.rb` entry point are the three left out, and that is named
explicitly rather than folded into "22 covered" meaning "22 fully verified".
**This round's gate figures are not a false green** — they were reproduced,
not relayed.

## Where a false-green risk still exists, named precisely

1. **"Covering 22 components" still invites over-reading**, for the same
   reason the last round flagged "covering 20 components": "touched by a
   test" is not "all four axes verified". `.reports/component-parity.md`
   this round names, per unit, exactly which of those 22 have real
   assertions behind every behaviour versus a touch-and-no-check or a
   touch-and-partial-check — the popover's badge widget, insensitive-at-0
   state and Done button; `input_handler.rb`'s RTL mirroring and ghost-click
   guard; `finished_page.rb`'s dark/light swap; `game_setup_dialog.rb`'s own
   Start-button click path. None of these are claimed as verified anywhere
   in this round's reports, but a reader who stops at "50/50, covering 22
   components" without opening `component-parity.md` would still walk away
   with a rosier picture than the evidence supports — exactly the risk named
   last round, now narrower in scope but not eliminated.
2. **`style.rb` and `log_utils.rb` have zero coverage of any kind** — not
   partial, zero. Nothing in this repo claims otherwise, but it is worth
   stating plainly rather than letting "22 of 25 covered" imply the
   remaining 3 are a rounding error: `rb.rb` is harmless (build plumbing,
   not a ported upstream unit), but `style.rb` and `log_utils.rb` are real
   ported upstream units (`data/style.css`/`style-dark.css` and
   `src/log_utils.py`) with real, if narrow, behavioural content
   (the dangling `sudoku-block` class reproduction; the in-memory log buffer
   feeding the About dialog's debug info) that no spec and no driver step
   touches.
3. **The generator-contract test substitution in `spec/generator_contract_spec.rb`**
   (documented in `.reports/test-parity.md`) is disclosed in the spec file's
   own header comment and in this round's reports, which is the correct
   behaviour per this skill — a substitution that is explained rather than
   silently counted as "ported" is not an excuse. It is named here only so a
   future pass does not read "113/113" as "113 byte-identical tests" without
   checking that one is a deliberate, documented, behaviourally-equivalent
   swap.

## What this round is not claiming

Nobody in this repo's history wrote "dropped deliberately", "not
applicable", "out of scope", or any of this skill's listed excuse
constructions, and nobody this round wrote a claim this round's direct
re-execution failed to reproduce. The accountability work this round found
is: the prior round's two concrete false-green risks (the stale "13/13
present" inventory headline, and the RSpec suite having never run) are both
now resolved with evidence, not just reasserted — and the gate's "covering N
components" framing still needs the per-component breakdown next to it, every
round, because the number itself will always undercount what "covered" needs
to mean.

## Verdict

Mostly clean. No excuse-language hit survives reading in context. The
specific false-green risks named last round (a stale status headline, a
never-run test command) are both independently reproduced as fixed this
round, not merely reasserted. The residual risk is the same shape as last
round, just smaller: "50 checks ... covering 22 components" is accurate as a
count of what ran, and would still be misread as "22 components fully
verified" by anyone who does not also read `.reports/component-parity.md`'s
per-unit breakdown — which is why that breakdown exists and is repeated here
rather than assumed understood.
