# Test parity — Sudoku-rb

| | |
|---|---|
| Upstream | `main` @ `2be119d` |
| Port | `ruby` @ `b0a9d76` |
| Upstream tests | 6 files, 113 `def test_*` methods total |
| Ported | **113 of 113**, one Ruby `it` per upstream `def test_*`, same file grouping |
| Suite actually runs | **yes** — re-run directly this round, not inferred |
| Test command | `nix develop --command xvfb-run -a rspec` (the devshell banner's own command) |

## This round's verification, independent of the commit message

The commit that claims this (`a1192eb`, "Port the upstream RSpec suite and
fix the devshell's test harness") says "113 examples, 0 failures". That claim
was re-run from scratch this round rather than trusted:

```
nix develop --command xvfb-run -a rspec
# Randomized with seed ...
# .................................................................................................................
# Finished in 9.14 seconds (files took 8.09 seconds to load)
# 113 examples, 0 failures
```

Reproduces. This is a real change from the state the prior report recorded:
previously `require "kettle/test/rspec"` raised `LoadError` before collecting
a single example, because the devshell had no path to that gem. `a1192eb`
added a separate test-only `nix/test/` bundlerEnv (kept out of
`packages.default`'s closure) that resolves it, and added
`lib/sudoku/rb.rb`, the entry point `spec/spec_helper.rb` requires
(`require "sudoku/rb"`), which previously did not exist either. Both of
those specific claims were checked by reading the files, not just by the
suite now passing.

## File-by-file census, counted directly rather than at the file level only

Last round's report explicitly stopped at a file-level count ("a full
name-by-name census ... was not completed ... it should still be done before
any of these are closed"). This round did it:

```
for f in test_board_conflicts test_board_core test_board_serialization \
         test_generator_contract test_input_handler test_preferences; do
  git show origin/main:tests/$f.py | grep -c '^    def test_'
done
```

| Upstream file | `def test_*` count | Port file | `it "test_..."` count |
|---|---:|---|---:|
| `tests/test_board_conflicts.py` | 11 | `spec/board_conflicts_spec.rb` | 11 |
| `tests/test_board_core.py` | 24 | `spec/board_core_spec.rb` | 24 |
| `tests/test_board_serialization.py` | 30 | `spec/board_serialization_spec.rb` | 30 |
| `tests/test_generator_contract.py` | 4 | `spec/generator_contract_spec.rb` | 4 |
| `tests/test_input_handler.py` | 20 | `spec/input_handler_spec.rb` | 20 |
| `tests/test_preferences.py` | 24 | `spec/preferences_spec.rb` | 24 |
| **Total** | **113** | | **113** |

Every port spec names its `it` block after the upstream `def test_*` it was
ported from (confirmed by reading all six spec files), so this is a real
name-preserving 1:1 census, not a count that happens to match.

## The one deliberate substitution, and why it is not an excuse

`tests/test_generator_contract.py` mocks `PuzzleGenerator.make_puzzle` (from
the third-party `sudoku` PyPI package upstream depends on) and asserts which
`sudoku_cls` keyword argument it was called with. The port's
`lib/sudoku/generator.rb` has no such dependency to mock — it builds puzzles
itself via its own `GridSolver`. `spec/generator_contract_spec.rb` keeps both
upstream test names and keeps the "returns two 9×9 lists" shape assertion
unchanged, and replaces the `sudoku_cls`-kwarg assertion with the port's own
equivalent seam: which `extra_units` the variant's generator enforces (empty
for Classic, the two main diagonals for Diagonal). This is documented in the
spec file's own header comment, is a like-for-like behavioural substitution
(same contract — "does this variant's generator enforce the right extra
constraints" — checked through the port's actual API instead of a mock of a
dependency the port doesn't have), and is not reported in this ledger as
"ported" without comment — it is called out explicitly here and in the
file.

## What is still not covered

- No `PORTING.md` exists on `ruby` (checked again this round) — nothing to
  cross-reference against a porting log, which is itself fine, but means
  this report is the only record of the generator-contract substitution
  above; it should not be allowed to drift from the spec file's own comment.
- The two `test/drive_*.rb` scripts remain real integration smoke tests (not
  unit tests) and are reported separately — see `.reports/component-parity.md`
  for what they do and do not assert. They are not part of the 113/113 count
  above and should not be added to it.
- Upstream's `tests/conftest.py` fixture helpers (`make_board_state`, etc.)
  were not ported as a shared file; each Ruby spec builds its own fixtures
  inline or via a local `let`/helper. This was not checked for whether it
  caused any duplicated-but-divergent fixture logic across the six spec
  files — a structural tidiness question, not a parity gap, since all 113
  examples pass.

## Verdict

Clean on this axis. 113 of 113 upstream unit tests have a named Ruby
counterpart, the count matches at the individual-test level (not just the
file level), and the suite was independently re-run this round and genuinely
passes — `rspec` is no longer a command that fails before collecting a single
example, which was last round's root finding. The one substitution
(generator contract) is documented, behaviourally equivalent, and disclosed
rather than hidden.
