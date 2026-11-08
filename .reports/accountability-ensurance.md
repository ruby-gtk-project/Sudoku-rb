# Accountability ensurance — Sudoku-rb

| | |
|---|---|
| Upstream | `main` @ `2be119d` |
| Port | `ruby` @ `e81851d` |

## This round's own finding: a false green, not a stale one

The prior `translation-parity.md` stated, unconditionally: "Clean on the
msgid-survival axis." That sentence was never true. It was reached by
checking a handful of known strings by hand (the shortcuts dialog, five
picked labels per language) and running `test/drive_translations.rb` — and
never once by running
`.claude/skills/translation-parity/scripts/catalogue.rb`, the tool this
org's own skill exists to make someone run, against upstream's whole message
surface. Doing that this round, for the first time across at least four
audit rounds of this fork, finds **20 upstream messages with no port
counterpart at all** — every string in
`data/io.github.sepehr_rs.Sudoku.metainfo.xml.in` and
`data/io.github.sepehr_rs.Sudoku.desktop.in`, because neither file has ever
existed in the port (`component-identification.md`, this round).

This is worse than the staleness this report flagged last round (reports a
commit behind the code they describe). A stale report is wrong about the
present because the present moved. **This report was wrong about the
present at the moment it was written**, because the check that would have
caught it was never run, in any round, on this fork. The method itself
(spot-check known strings, don't run the census) cannot find a message the
auditor does not already know to look for — and nobody looked for the
desktop file or the metainfo file, because `component-identification.md`'s
own method (walk `src/` and `data/blueprints/` only) never surfaced them
either. Two separate ledgers' methods shared the same blind spot, and each
one's "clean" verdict quietly leaned on the other never having looked either.

**The lesson this round is recording, not just the gap**: "I checked five
known strings in five languages and they were right" is evidence those five
are right. It is not evidence the catalogue is complete, and stating the
second thing on the strength of the first is exactly the shape of claim this
skill exists to catch, whether or not anyone intended it as one.

## Grep for excuse language — re-run fresh this round

```sh
.claude/skills/accountability-ensurance/scripts/find-excuses.sh .
```

Every hit, read in context:

| Hit | Location | Verdict |
|---|---|---|
| `not ported` | `spec/input_handler_spec.rb:279,332` | Not an excuse. Disclosing that the ghost-click tests are new, port-only coverage with no upstream test to port against — the correct, required disclosure for `## Extra` rows, not a justification for a gap. |
| `by design` | `.reports/test-parity.md:47` (previous version) | Benign in context — describes why `log_utils_spec.rb` has no 1:1 upstream row (there is no `test_log_utils.py`), not an excuse for missing port behaviour. Rewritten regardless in the regenerated report to remove the phrase, since the construction itself is listed and a future reader should not have to re-derive that it was benign. |
| `not ported` | `.reports/test-parity.md:73` (previous version) | Same as above — describing `conftest.py` fixtures not being ported as a *fact*, immediately followed by "not a parity gap since all examples pass." Honest, not toothless in context, but rewritten to state the behaviour plainly rather than rely on the reader following the qualifier. |
| `N/A` | `.reports/component-inventory.md:76` | Not an excuse. States that *upstream's own* GSettings schema defines zero keys — a fact about upstream, re-confirmed this round by reading `data/io.github.sepehr_rs.Sudoku.gschema.xml` directly, not a claim that a port obligation doesn't apply. |
| the whole construction table | `.reports/accountability-ensurance.md:30` (previous version) | The skill's own reference table, quoted for documentation. Not a live excuse. |
| `no Ruby equivalent` | `lib/sudoku/generator.rb:17` | Not an excuse — the very next sentence is "so the engine lives here," and 448 lines of `GridSolver`/`PuzzleGenerator` follow, implementing the behaviour from scratch. The comment states a true fact about why there's no 1:1 dependency mapping, immediately followed by the real implementation, not a justification for skipping it. |

**No genuine excuse construction was found in `lib/`, `exe/`, or any
`.reports/*.md` file this round.** Every hit the scanner found was either a
correct `## Extra`-style disclosure of new, non-upstream test coverage, or a
true statement about upstream's own state (an empty GSettings schema),
immediately followed by the actual implementation rather than used to avoid
writing one. `PORTING.md` still does not exist on `ruby` — there is no
document at the branch root that could be read as settled architecture; the
only prose this audit found and had to judge is inside `.reports/` itself.

## The false-green question, checked against this round's own re-execution

- `nix develop --command xvfb-run -a ruby test/drive_game.rb` → `DRIVE OK`,
  **45 of 45 checks passed**, re-run directly.
- `nix develop --command xvfb-run -a ruby test/drive_translations.rb` →
  `DRIVE OK` for all five languages, 45 `ok` lines total, re-run directly.
- `nix develop --command xvfb-run -a rspec` → **140 examples, 0 failures**,
  re-run directly — not the 121 the previous `test-parity.md` stated (see
  that report: the number was stale, two commits behind, by the time this
  round started).
- Independently regenerated `translation-parity.yaml` from the actual
  census scripts rather than trusting any prior document's summary —
  this is the step that found the 20-message gap.
- Independently re-diffed `data/style.css`/`style-dark.css` against
  `Sudoku::Style::LIGHT`/`DARK` byte-for-byte rather than trusting
  `spec/style_spec.rb`'s own internal diff logic to be reporting correctly.

**This round's own runtime numbers are not a false green**: 45/45 and
140/0-failures were reproduced from a clean re-run, not copied from a
report or a commit message.

## Where a false-green risk still exists, named precisely

1. **The component-identification method itself had a blind spot**, and
   this report cannot certify the gap just found is the last one of its
   kind — only that widening the scan to upstream's whole `data/` tree
   (rather than `src/` + `data/blueprints/`) found two real misses this
   time. The next round should widen further still: `po/POTFILES` is the
   authoritative list of every file upstream's own `xgettext` reads, and
   has not itself been diffed against the port's file set.
2. **`test-parity.md`'s "Extra" count (27 = 140 − 113) is not itemized
   line-by-line this round** beyond confirming the two source files/blocks
   exist and run. Stated as a residual item in that report rather than
   rounded up to a claim of full itemization.
3. **No `PORTING.md` or `TEST_PARITY.md` exists at the branch root.** Every
   ledger in this audit lives only under `.reports/`, which is where this
   round's task asked for them, but it means the skills' own canonical
   filenames have never been created on this branch, in any round.

## Verdict

**Not clean**, and the most serious finding is not a missing feature but a
false claim: the prior round's `translation-parity.md` asserted parity on
an axis it never actually measured, because none of at least four prior
audit rounds ran the one script that would have measured it. That false
green is now corrected, the underlying component gap (no `.desktop.in`, no
metainfo file in the port) is named in `component-parity.md` and
`component-identification.md`, and the 20 affected messages are enumerated
in `translation-parity.md`. No excuse-language construction was found
laundering any gap in this port's own prose — the gap that existed was
simply never checked for, rather than checked for and explained away.
