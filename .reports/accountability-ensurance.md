# Accountability ensurance — Sudoku-rb

| | |
|---|---|
| Upstream | `main` @ `2be119d` |
| Port | `ruby` @ `46c2887` |

## This round's own finding: the reports themselves were the stalest artifact in the repo

Before touching the grep or the drivers, the state of `.reports/` at the
start of this round was checked against `git log`. The five parity reports
(`component-identification.md`, `component-parity.md`, `test-parity.md`,
`translation-parity.md`, `accountability-ensurance.md`) were last written at
commit `69463f2` and still named `b0a9d76` as the port HEAD and "50 checks,
0 failed, covering 22 components" as the gate — while the actual `ruby` HEAD
had already moved to `46c2887`, whose own commit message claims to have
closed four of the specific gaps those stale reports named (log_utils
coverage, popover badges/Done, the dialog click path, the illustration
swap). Had this round trusted the files on disk instead of re-deriving from
the repository, it would have reported a materially out-of-date "unverified"
list as current. This is itself exactly the kind of false-green risk this
skill exists to catch — a report that is accurate about a past commit read
as if it describes the present one. All four reports in this round were
rewritten from a fresh direct re-run against the current HEAD rather than
patched or trusted.

## Grep for excuse language — re-run fresh this round

```
grep -rniE "TODO|FIXME|not implemented|for now|in a future|not yet|unimplemented|placeholder\b|stub\b|dropped deliberately|not applicable|no ruby analogue|out of scope|not needed|by design|by choice|deliberate simplification|streamlined|modernised away|bindings do not support|skipped" lib exe .reports AGENTS.md CLAUDE.md
```

(`PORTING.md` still does not exist on `ruby`.) No new hit beyond the two
already read-in-context and judged benign in the prior round:

- `lib/sudoku/popover_manager.rb:135` — a debug log line on a no-op popdown,
  not an admission of a missing feature.
- `lib/sudoku/sudoku_cell.rb:181` — a performance short-circuit comment, not
  a scope cut.

`lib/sudoku/popover_manager.rb:151`'s allocation-timing comment is unchanged
GTK prose. **On the excuse-language axis, the port remains clean.**

## The false-green question, checked against this round's own re-execution

- `nix develop --command xvfb-run -a ruby test/drive_game.rb` → `DRIVE OK`,
  50 `ok` lines, re-run directly.
- `nix develop --command xvfb-run -a ruby test/drive_translations.rb` →
  `DRIVE OK`, 9 `ok` lines, re-run directly.
- `nix develop --command xvfb-run -a rspec` → `121 examples, 0 failures`,
  re-run directly.
- 50 + 9 = 59, matching the runtime gate's "59 checks ... covering 23
  components" exactly. 121 = 113 upstream-ported (recounted file-by-file in
  `test-parity.md`) + 8 new, disclosed-as-new `log_utils_spec.rb` examples.
- Each of the four gaps `46c2887`'s commit message claims to close
  (log_utils coverage, popover badges/insensitive-at-0/Done, the Start-button
  click path, the illustration swap) was independently confirmed by reading
  the new spec/driver code, not accepted from the commit message alone — see
  `component-parity.md` for the line-by-line mapping.

**This round's gate figures are not a false green** — they were reproduced
from a clean re-run, and the component-count increase (22 → 23) was traced
to a specific named unit (`log_utils.rb`) gaining real coverage, not to a
redefinition of what counts as "covered".

## Where a false-green risk still exists, named precisely

1. **"Covering 23 components" still means "touched by at least one
   assertion", not "every behaviour of that component verified".**
   `component-parity.md` names the per-unit residue: `style.rb` is the one
   unit with zero coverage of any kind; RTL/ghost-click in
   `input_handler.rb` remain untested on both sides (upstream-inherited, not
   a port regression); translated `msgstr` values for three of five shipped
   languages have never been checked.
2. **The 8 new `log_utils_spec.rb` examples are correctly disclosed as
   new-not-ported** in both the spec file's own header comment and
   `test-parity.md`. This is the right shape of accountability — a gap was
   closed with real new coverage and labelled as such, not folded silently
   into "113/113 upstream parity" to make the number look bigger.
3. **No excuse language anywhere in `lib/`, `exe/`, or the reports
   themselves** was found this round, including in the newly-added files.

## Verdict

Not clean, but for a reason this report names rather than one it would have
missed: `style.rb` remains genuinely unverified, and three of five
languages' translated text remains unchecked. Both are real, stated plainly,
and have been named across every round rather than quietly dropped. The more
serious risk this round actually found — that the parity reports on disk
were a full commit behind the code they claimed to describe — was caught by
checking `git log` against the reports' own stated HEAD before trusting
anything else in this repo, and is the reason all five reports were rebuilt
from a fresh re-run this round rather than incrementally patched.
