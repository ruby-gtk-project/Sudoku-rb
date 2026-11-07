# Accountability ensurance — Sudoku-rb

## Grep for excuse language

```
grep -rniE "TODO|FIXME|not implemented|for now|in a future|not yet|unimplemented|placeholder|stub|dropped deliberately|not applicable|no ruby analogue|out of scope|not needed|by design|by choice|deliberate simplification|streamlined|modernised away|bindings do not support|upstream's own TODO|skipped" lib exe .reports PORTING.md AGENTS.md CLAUDE.md
```

No `PORTING.md` exists on `ruby`. No hit in `lib/`, `exe/`, `AGENTS.md`,
`CLAUDE.md` matches an excuse construction. The one incidental match in
`lib/sudoku/popover_manager.rb:151` ("allocation when the two are not yet
related") is a comment about GTK widget-allocation timing, not an excuse for
missing work — read in context, it explains *why* a position calculation is
deferred to an idle callback, not that a feature was skipped. No hit in this
codebase is a gap wearing a justification. **On the excuse-language axis
specifically, the port is clean.**

## The actual accountability problem found this round: a false-green risk, not an excuse

This skill also covers "whenever a parity ledger cites a document as
authority for a gap" and "a green claim that rests on something never
executed" — the second of which this round found, twice:

1. **`.reports/component-inventory.md`'s own status line.** Before this
   round, it stated "Every user-facing component now has a port file... All
   13 component sections below are **present**" and treated that as the
   headline. Read literally that is true — every file exists — but a reader
   skimming only that line would walk away believing the UI is done. It is
   not an excuse (nothing is blamed on upstream, nothing is called "out of
   scope"), but it is the same failure mode in miniature: a status claim
   that invites a reader to stop checking. `.reports/component-parity.md`
   (this round) names, component by component, which of those 13-plus-7
   non-UI files were actually driven versus merely opened-and-closed by
   `test/drive_game.rb` with zero assertions — preferences dialog, how-to-
   play dialog, shortcuts dialog's own presentation, and the whole
   `application.rb`/About-dialog surface. "Present" was true; "done" was not
   demonstrated, and the inventory's own phrasing did not distinguish the
   two.

2. **The runtime gate itself: `drive_ok=true, 31 checks passed, 0 failed,
   covering 20 components`.** This is the literal green claim the task
   asked this audit to treat with suspicion rather than accept. It is
   accurate as a report of what ran — both drivers were re-executed this
   round and both do print `DRIVE OK` with exactly those counts. The false-
   green risk is in how "covering 20 components" reads: it is true that 20
   component files are *touched* by a `step` in one driver or the other, but
   as `.reports/component-parity.md` shows, 4 of those 20 are touched with
   **no check at all** following the touch (preferences, help dialog,
   shortcuts dialog, and — not even touched — `application.rb`), and a
   further 6 have no coverage of their most consequential behaviour (cell
   feedback timeouts, popover badges, the full keyboard map, variant
   preference toggles, the stylesheet, the log buffer). A reader who takes
   "31/31, covering 20 components" as "the UI is verified" has been misled
   by the word "covering" doing more work than the evidence supports. The
   fix is not a smaller number — it is the per-component breakdown in
   `.reports/component-parity.md`, which this round produced specifically
   so "covering 20 components" cannot be read as "20 components verified"
   again.

3. **The RSpec suite has never successfully run, in any commit on this
   branch, and nothing in the repo says so until this round.** `rake spec` /
   the devshell's own named run command fails at `require "kettle/test/
   rspec"` before collecting a single example (`.reports/test-parity.md` has
   the transcript). There is no green claim resting on this *in this repo*
   — no commit message or report claimed the spec suite passes — but the
   devshell banner presents the command as a thing you can run, and a port
   that is "finished" while its only unit-test entry point has never worked
   is exactly the gap this skill exists to surface before anyone writes a
   summary that omits it.

## What this round is not claiming

Nobody in this repo's history wrote "dropped deliberately", "not
applicable", "out of scope", or any of this skill's listed constructions.
The accountability failure found here is narrower and more specific than
that: a true statement ("present", "31 checks passed") was reused as if it
answered a broader question ("is this component correct", "is this gate a
verification of the whole UI") that it does not answer. That gap is now
closed by `.reports/component-parity.md` and `.reports/test-parity.md`
naming, per component and per test file, what was and was not actually
checked.

## Verdict

Not clean, on the "false green" axis specifically — not because anyone
wrote a dishonest sentence, but because two true, narrow claims
("file present", "31/31 drive checks") were standing in for a broader claim
("the UI has parity", "the port is tested") that neither one supports. No
excuse-language hit. The grep this skill runs is clean; the inference a
reader would draw from the gate and the existing inventory is not, and that
inference is this report's actual finding.
