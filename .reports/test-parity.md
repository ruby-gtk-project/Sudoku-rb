# Test parity — Sudoku-rb

| | |
|---|---|
| Upstream | `main` @ `2be119d` |
| Port | `ruby` @ `46c2887` |
| Upstream tests | 6 files, 113 `def test_*` methods total |
| Ported from upstream | **113 of 113**, one Ruby `it` per upstream `def test_*`, same file grouping (unchanged from last round — recounted this round, matches) |
| Port-only additions (no upstream counterpart) | 8 — `spec/log_utils_spec.rb` |
| Suite actually runs | **yes** — re-run directly this round |
| Test command | `nix develop --command xvfb-run -a rspec` (the devshell banner's own command) |

## Re-verified directly this round

```
nix develop --command xvfb-run -a rspec
# Randomized with seed ...
# 121 examples, 0 failures
```

121 = 113 (upstream-ported, unchanged census below) + 8 new examples in
`spec/log_utils_spec.rb`, added in `46c2887` to close the zero-coverage gap
the prior `component-parity.md` named for `lib/sudoku/log_utils.rb`.

## File-by-file census against upstream, recounted this round

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

Unchanged from the last round — upstream has not added or removed a test
file or method since `2be119d`, and no port spec file ported from upstream
was touched by `46c2887` (only the new, disclosed-as-new, `log_utils_spec.rb`
was added, which maps to no upstream test file by design — see below).

## `spec/log_utils_spec.rb` is new coverage, not a ported upstream test — and says so

Its own header comment: "Upstream ships no dedicated test module for
log_utils.py, so there is no 1:1 upstream test to port here; this closes the
zero-coverage gap the component-parity report named for this unit." Read in
full — the claim is accurate: `origin/main:tests/` has no `test_log_utils.py`
and never did. This is legitimately new test coverage for a real upstream
unit (`src/log_utils.py`) that had none to port, disclosed as such rather
than silently inflated into the 113/113 upstream-parity count above.

## The one deliberate substitution, unchanged from last round

`tests/test_generator_contract.py` mocks a third-party `PuzzleGenerator` the
port has no equivalent dependency for; `spec/generator_contract_spec.rb`
substitutes an equivalent assertion against the port's own generator seam
(`extra_units` per variant), disclosed in the spec file's own header and in
this report. Re-confirmed present and unchanged this round.

## What is still not covered

- No `PORTING.md` exists on `ruby` (checked again this round).
- The two `test/drive_*.rb` scripts remain integration smoke tests, reported
  separately in `component-parity.md`, and are correctly not folded into the
  113/121 counts above.
- Upstream's `tests/conftest.py` fixture helpers were not ported as a shared
  file (unchanged finding, not a parity gap since all examples pass).

## Verdict

Clean on the upstream-test-survival axis: 113 of 113 upstream unit tests
still have a named Ruby counterpart, independently recounted this round, and
the full suite (121 examples including the new, disclosed, non-upstream
`log_utils_spec.rb`) was re-run from scratch and genuinely passes.
