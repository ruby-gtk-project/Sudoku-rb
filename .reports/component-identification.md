# Component identification — audit of the existing census

| | |
|---|---|
| Upstream | `main` @ `2be119d` |
| Port | `ruby` @ `b0a9d76` |

Upstream has not moved since the last round (`origin/main` is still `2be119d`),
so `.reports/component-inventory.md`'s census is re-checked for drift against
the port, not re-walked from zero. Re-spot-checked this round:

- Every `lib/sudoku/<thing>.rb` the inventory names still exists.
- The port gained one new file since the inventory was written,
  `lib/sudoku/rb.rb` — the gem's `require "sudoku/rb"` entry point that
  `spec/spec_helper.rb` needs. It is not a ported upstream unit (upstream has
  no equivalent single-file entry point); it is build plumbing, correctly
  outside the 13-UI/11-non-UI census.
- `po/LINGUAS` still lists `de, fa, nl, vi, zh` — the previously-noted stale
  blocker (ports omitting `de`) was already corrected before the last round
  and remains correct.
- The two msgids `.reports/translation-parity.md` found missing from
  `po/sudokugame.pot` last round (`help_dialog.rb`'s two multi-line `_()`
  calls) are now present in the pot and all five `.po` files — see
  `.reports/translation-parity.md` for the verification.

No new upstream file was found missing a port-side counterpart. The unit list
(13 UI sections + 11 non-UI files, 25 `lib/sudoku/*.rb` files total once
`rb.rb` is excluded as non-census plumbing) is unchanged from last round.
What changed this round is how much of that census has actual runtime
verification behind it — that comparison is `component-parity`'s job, and the
answer moved substantially since the last report (see
`.reports/component-parity.md`): the port went from 0/6 upstream test files
ported and an RSpec harness that could not load, to 113/113 example-for-example
parity with upstream's own `def test_*` count, actually executed. The
identification-level finding from last round (file existence ≠ parity) still
holds and is still the right line to draw — it is just that more of the
previously-"present-only" units now have axis-4/5 evidence behind them than
they did.
