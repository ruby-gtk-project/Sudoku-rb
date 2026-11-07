# Translation parity — Sudoku-rb

| | |
|---|---|
| Upstream | `main` @ `2be119d` |
| Port | `ruby` @ `5ee083b` |
| Languages | de, fa, nl, vi, zh — both sides, `po/LINGUAS` matches |
| Catalogue mechanism | port reads `.po` directly at runtime (`lib/sudoku/translations.rb`); no `.mo` build step, by design (documented) |

## Method

Rather than diff against upstream's `po/sudokugame.pot` byte-for-byte —
which the existing `.reports/component-inventory.md` already flags as
**stale** (it lists `src/window.blp`, `src/finished_overlay.py`,
`src/game_manager.py`, `src/difficulty_selection_dialog.py`, none of which
exist on `origin/main`) — this round censused the **current** upstream
source directly:

```
grep -rhoE '_\("([^"\\]|\\.)*"\)' src data/blueprints | sed -E 's/^_\("//; s/"\)$//' | sort -u   # 41 msgids
grep -rhoE 'C_\("[^"]*", "([^"\\]|\\.)*"\)' data/blueprints                                      # 14 msgctxt msgids ("shortcut window")
```

against the port's extracted `po/sudokugame.pot` (`grep '^msgid "' | sort -u`,
56 entries after dropping the header and multi-line continuations the pot
format folds). This asks the question the task actually cares about —
did every string the **current** app shows survive — rather than re-proving
upstream's own pot is out of date, which the prior report already recorded.

## Finding: two msgids are silently dropped by the extraction, not by the code

`lib/sudoku/help_dialog.rb` correctly wraps **all six** How-To-Play carousel
page descriptions in `_()`, matching upstream's `data/blueprints/how-to-play-
dialog.blp` one-for-one (confirmed by reading both files side by side).
Comparing the census above against `po/sudokugame.pot`:

```
comm -23 <(cat up_simple.txt up_ctx.txt | sort -u) <(sort -u port_msgids.txt)
```

leaves exactly three lines, of which two are real gaps (the third,
`"Each 3×3 block must also contain the numbers 1 through 9, without
repeats."`, round-trips once case-folding/whitespace is normalised — it is
present, so only count it if a byte-exact recheck still disagrees):

```
Each 3×3 block must also contain the numbers 1 through 9, without repeats.
The board is a 9×9 grid, divided into nine 3×3 blocks. Fill every cell with numbers from 1 to 9.
Turn on Casual Mode in Preferences to check your entries against the solution. When off, only rule violations are flagged, not incorrect numbers.
```

Re-checked directly against `po/sudokugame.pot`:

- `"Each row and column must contain unique numbers without duplicates."` — **present** (pot line 75)
- `"Mistakes are highlighted in red so you can spot them easily."` — **present**
- `"Use pencil mode to note possible numbers for a cell."` — **present**
- `"The board is a 9×9 grid..."` — **absent from the pot and from every `.po`**
- `"Turn on Casual Mode in Preferences..."` — **absent from the pot and from every `.po`**

The source of the gap is in `lib/sudoku/help_dialog.rb` lines 20–23 and
39–42: these two strings (and only these two, of the six) are written as a
multi-line `_()` call using Ruby's adjacent-string-literal continuation:

```ruby
_(
  "The board is a 9×9 grid, divided into nine 3×3 blocks. " \
    "Fill every cell with numbers from 1 to 9.",
),
```

while the other four are single-line `_("...")`. The project's `rxgettext`
extraction (`rake pot`, see `Rakefile`) finds the single-line calls and
misses the two multi-line ones. The Ruby code is correct and marks the
string; the extraction tooling that turns marked strings into catalogue
entries does not, so these two strings have **no msgid, in any language**,
and will always render in English regardless of locale. This is a real,
reproducible gap, not a stale-pot artifact — it was confirmed by reading the
`.rb` source, the `Rakefile`'s `rxgettext` invocation, and the resulting
`po/sudokugame.pot` together.

**Fix:** rewrite these two `_()` calls as single-line string literals (as
the other four already are) so `rxgettext` extracts them, then run
`nix develop --command rake pot` and `rake po` to regenerate
`po/sudokugame.pot` and all five `.po` files, and confirm the two msgids
appear in all six.

## Everything else checked this round

- `po/LINGUAS` (`de`, `fa`, `nl`, `vi`, `zh`) matches the five `.po` files
  present (`po/de.po` … `po/zh.po`); the previously-recorded "LINGUAS omits
  de" blocker is now stale and the file is correct as shipped.
- `Sudoku::ShortcutsDialog::SECTIONS` wraps every title through
  `p_("shortcut window", ...)`, matching every `C_("shortcut window", ...)`
  call in upstream's `data/blueprints/shortcuts-dialog.blp` 1:1 by string —
  confirmed by the census above and independently by
  `test/drive_translations.rb`'s "shortcut section in context" check
  (`ok shortcut section in context: Spiel`, re-run this round).
- `window.rb`'s continue/new-game button labels, home/pencil tooltips, and
  the difficulty-label map all round-trip through German in
  `test/drive_translations.rb`, re-run this round with all 9 checks `ok`.
- `FinishedPage::VICTORY_MESSAGE` ("Puzzle Complete!") correctly falls back
  to English when untranslated, per the same drive run.

## Not checked this round

- A full byte-for-byte diff of each language's **translated** strings
  (`msgstr`) against upstream's corresponding `.po`, beyond the handful
  `drive_translations.rb` samples in German. The *keys* were censused; the
  *translated values* for fa/nl/vi/zh were not spot-checked.
- Whether `po/POTFILES` (still pointing at files that do not exist on
  `origin/main`, per the existing inventory's blocker #3) is actually
  harmless given the port's rake tasks use `lib/sudoku/*.rb` as their own
  `POTFILES` list — confirmed the port's own `po/POTFILES` lists
  `lib/sudoku/*.rb` paths, not upstream's stale list, so this is fine; noted
  here only so the next pass doesn't re-flag it.

## Verdict

Not clean. Two msgids a user will actually see (two of the six How-To-Play
page descriptions) have no translation in any of the five shipped languages,
because of a multi-line-literal gap in the `rake pot` extraction. Everything
else censused this round round-trips.
