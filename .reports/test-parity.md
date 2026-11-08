# Test parity — Sudoku-rb

| | |
|---|---|
| Upstream | `main` @ `2be119d` |
| Port | `ruby` @ `e81851d` |
| Upstream tests | 6 files, 113 `def test_*` methods total |
| Ported from upstream | **113 of 113** — one `it` per upstream `def test_*`, same file grouping |
| Port-only additions (no upstream counterpart) | 27 — see `## Extra` below |
| Suite actually runs | **yes** — re-run from scratch this round, not trusted from a prior round's number |
| Test command | `nix develop --command xvfb-run -a rspec` (the devshell banner's own command) |

## Re-run directly this round

```
nix develop --command xvfb-run -a rspec
# Randomized with seed 44619
# 140 examples, 0 failures
```

**140, not the 121 the last-written `test-parity.md` claimed.** That number
was stale, not wrong when written: `82294ee` and `e81851d`, both after the
commit the old report was pinned to, added `spec/style_spec.rb` and extended
`spec/input_handler_spec.rb` with ghost-click and RTL blocks, and neither
`.reports/test-parity.md` nor `.reports/translation-parity.md` was
regenerated to match. A parity report that silently falls behind the suite
it describes is exactly the failure mode `accountability-ensurance.md`
names this round — see that report.

## File-by-file census against upstream, recounted this round

```sh
for f in test_board_conflicts test_board_core test_board_serialization \
         test_generator_contract test_input_handler test_preferences; do
  git show origin/main:tests/$f.py | grep -c '^    def test_'
done
```

| Upstream file | `def test_*` count | Port file | `it "test_..."` count | State |
|---|---:|---|---:|---|
| `tests/test_board_conflicts.py` | 11 | `spec/board_conflicts_spec.rb` | 11 | ported |
| `tests/test_board_core.py` | 24 | `spec/board_core_spec.rb` | 24 | ported |
| `tests/test_board_serialization.py` | 30 | `spec/board_serialization_spec.rb` | 30 | ported |
| `tests/test_generator_contract.py` | 4 | `spec/generator_contract_spec.rb` | 4 | ported, one substitution (below) |
| `tests/test_input_handler.py` | 20 | `spec/input_handler_spec.rb` | 20 | ported |
| `tests/test_preferences.py` | 24 | `spec/preferences_spec.rb` | 24 | ported |
| **Total** | **113** | | **113** | |

Unchanged from prior rounds — upstream has not added or removed a test file
or method since `2be119d`, and the two new spec additions
(`spec/style_spec.rb`, the ghost-click/RTL blocks in
`spec/input_handler_spec.rb`) are additions *beyond* the 113 1:1 rows, not
replacements for any of them — each upstream-ported `it` in the census above
is unchanged by the files that landed since the last round.

## The one deliberate substitution (unchanged from prior rounds)

`tests/test_generator_contract.py` mocks a third-party `PuzzleGenerator` the
port has no equivalent dependency for; `spec/generator_contract_spec.rb`
substitutes an equivalent assertion against the port's own generator seam
(`extra_units` per variant). Disclosed in the spec file's own header and
here. Re-confirmed present and unchanged this round.

## `## Extra` — port-only coverage, outside the 113/113 count

None of these port a named upstream test; each is disclosed as new in its
own file header, which is the right shape of accountability per this skill
(a gap closed with real coverage, labelled as such, never folded silently
into the 113/113 to inflate it):

- `spec/log_utils_spec.rb` (8 examples) — `src/log_utils.py` has no dedicated
  upstream test module.
- `spec/style_spec.rb` (new this round) — `data/style.css`/`style-dark.css`
  have no upstream test at all (upstream ships no stylesheet test of any
  kind); closes what was this port's one remaining zero-coverage unit.
- `spec/input_handler_spec.rb`'s ghost-click guard and RTL-mirroring blocks
  (new this round) — upstream's own `tests/test_input_handler.py` exercises
  neither; both are genuinely new coverage against the port's own code, not
  a port of anything upstream wrote.

27 extra examples (140 − 113) is consistent with 8 (log_utils) + the new
additions in `style_spec.rb` and the `input_handler_spec.rb` blocks; the
exact per-file breakdown of the newest 19 was not re-itemized line-by-line
this round beyond confirming the two files/blocks exist and run — a residual
item for the next round rather than a claim made here as settled.

## What is still not covered

- No `PORTING.md` exists on `ruby` (checked again this round — still absent).
- No `TEST_PARITY.md` exists at the branch root either; this ledger has
  lived only at `.reports/test-parity.md` for every round so far, which is
  where the task that commissioned this audit asked for it, but it means
  the skill's own canonical location (`TEST_PARITY.md` at the branch root)
  has never been created. Named here rather than silently matched to a
  different filename.
- The two `test/drive_*.rb` scripts are integration smoke tests, reported in
  `component-parity.md`, and are correctly not folded into the 113/140
  counts above.
- Upstream's `tests/conftest.py` fixture helpers were not ported as a shared
  spec-support file (unchanged finding, not a parity gap since all examples
  pass without one).

## Verdict

Clean on the upstream-test-survival axis: 113 of 113 upstream unit tests
still have a named Ruby counterpart, independently recounted this round
file-by-file, and the full suite (140 examples, up from the 121 the last
report claimed) was re-run from scratch and genuinely passes. **Not fully
clean as a report-hygiene matter**: the number this report's predecessor
shipped (121) was already two commits stale at the moment this round
started, which is the finding `accountability-ensurance.md` leads with.
