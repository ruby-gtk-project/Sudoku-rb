# Test parity — Sudoku-rb

| | |
|---|---|
| Upstream | `main` @ `2be119d` |
| Port | `ruby` @ `5ee083b` |
| Upstream tests | 6 files, census below |
| Ported | **0** |
| Gaps | **all of them** |
| Test command | `rake spec` / the devshell's banner command — **does not run**, see below |

## Upstream census

Upstream's own build declares and runs a real unit-test suite, independent
of the `test/drive_*.rb`-style manual scripts this port has:

```
pytest.ini
tests/conftest.py
tests/meson.build
tests/test_board_conflicts.py
tests/test_board_core.py
tests/test_board_serialization.py
tests/test_generator_contract.py
tests/test_input_handler.py
tests/test_preferences.py
```

Sampled `tests/test_board_core.py`: real `pytest` classes (`TestIsClue`,
`TestGetCorrectValue`, …) asserting specific board behaviours — clue
detection, correct-value lookup — against literal puzzle/solution fixtures
built through `tests/conftest.py`'s `make_board_state`. This is upstream's
unit-test layer for exactly the logic the port's `lib/sudoku/board.rb`,
`lib/sudoku/generator.rb`, `lib/sudoku/preferences.rb`,
`lib/sudoku/input_handler.rb` and `lib/sudoku/classic_sudoku.rb` /
`diagonal_sudoku.rb` claim to have ported. A full name-by-name census (every
`def test_*` across the six files) was not completed to individual test
granularity this round because the count at the file level already settles
the question below; it should still be done before any of these are closed.

## Port side

```
find . -iname '*_spec.rb' -o -iname 'test_*.rb' -o -iname '*_test.rb'
```

finds nothing. `spec/` holds only the kettle-jem scaffold
(`spec/spec_helper.rb`, `spec/README.md`) with **zero `*_spec.rb` files**.
`test/` holds `test/drive_game.rb` and `test/drive_translations.rb` — both
are manual, no-assertion-framework driver scripts of the kind this skill
explicitly excludes from a census (`*driver*` is on the harness-file
exclusion list) and which are integration smoke tests of the running GTK
app, not unit tests of board/generator/preferences/input-handler logic.
Neither driver imports, calls, or in any way exercises
`Sudoku::Board#is_clue?`, `#get_correct_value`, conflict detection, the
generator's difficulty contract, or `Sudoku::Preferences` in isolation —
they only touch that logic indirectly, through whatever a scripted game
happens to do.

**Zero of the six upstream pytest files has a Ruby counterpart of any kind.**
Parity is 0/6 files (and 0 of however many individual `def test_*` cases they
contain — stop here rather than pad a per-test table, matching this skill's
"When upstream has no tests" degenerate-ledger guidance, inverted: here
upstream has tests and the port inherited none of them).

## The suite does not run — this is not merely "0 tests", it is "cannot run"

The devshell banner (`flake.nix` `shellHook`) names the run command:

```
ruby -e 'require "rspec/core"; exit RSpec::Core::Runner.run(["--format", "progress", "--require", "spec_helper", "spec"])'
```

Running it inside `nix develop`:

```
Failure/Error: require "kettle/test/rspec"
LoadError:
  cannot load such file -- kettle/test/rspec
No examples found.
Finished in 0.00005 seconds (files took 0.09392 seconds to load)
0 examples, 0 failures, 2 errors occurred outside of examples
```

`spec/spec_helper.rb` (line 23) requires `kettle/test/rspec`, which is not
resolvable in this devshell's gem environment. The RSpec harness the project
scaffolding installed has never successfully loaded, let alone run a test,
in this environment — confirmed by running it directly, not inferred from
absence. This is independent of the 0/6 file-count gap above: even if the
six pytest files were ported to `spec/*_spec.rb` today, the harness as
currently configured would still fail before reaching a single example.

## What test parity requires here

1. Fix `spec/spec_helper.rb` / the bundle so `rake spec` can load and run
   at all — currently 0 examples run for a reason that has nothing to do
   with whether specs exist.
2. Census all `def test_*` methods in the six `tests/test_*.py` files
   individually (not just at the file level, as done here) and give each one
   a named Ruby counterpart under `spec/`, one file per upstream file, per
   this skill's "keep the upstream suite's file structure" rule.
3. Re-run the port's census script against the result and report the two
   counts, not an adjective.

## Verdict

Not clean. 0/6 upstream test files ported, and the one command the devshell
names for running specs fails before collecting a single example. The two
`test/drive_*.rb` scripts are real and do pass (confirmed by direct run,
`DRIVE OK` both times), but they are integration smoke tests the port wrote
for itself — they belong under an `## Extra` list, not against this ledger's
count, and they inherit none of upstream's pinned board/generator/
preferences/input-handler behaviour.
