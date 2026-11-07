# Translation parity — Sudoku-rb

| | |
|---|---|
| Upstream | `main` @ `2be119d` |
| Port | `ruby` @ `b0a9d76` |
| Languages | de, fa, nl, vi, zh — both sides, `po/LINGUAS` matches |
| Catalogue mechanism | port reads `.po` directly at runtime (`lib/sudoku/translations.rb`); no `.mo` build step |

## The gap the last round found is fixed — re-verified directly, not from the commit message

The last round found two msgids (of 41 simple + 14 context-keyed upstream
strings) silently dropped by the port's `rxgettext` extraction, because
`lib/sudoku/help_dialog.rb` wrote exactly two of its six How-To-Play page
descriptions as multi-line adjacent-string-literal `_()` calls, which
`rxgettext` does not find. `a1192eb`'s commit message claims this was fixed
and the catalogues regenerated. Re-checked directly rather than trusted:

```
grep -n "board is a 9" po/sudokugame.pot po/de.po po/fa.po po/nl.po po/vi.po po/zh.po
grep -n "Casual Mode in Preferences" po/sudokugame.pot po/de.po po/fa.po po/nl.po po/vi.po po/zh.po
```

Both strings now appear in the pot and in all five `.po` files. Reading
`lib/sudoku/help_dialog.rb` confirms the source fix: both calls are now
single-line `_("...")` literals, matching the other four carousel-page
strings' style. This closes the one confirmed real bug the last round's audit
produced.

## Method (unchanged from last round, re-run)

Rather than diff against upstream's `po/sudokugame.pot` byte-for-byte (which
is known-stale on *upstream's own side* — it still lists files like
`src/window.blp` and `src/game_manager.py` that don't exist on current
`origin/main`), this round re-censused the **current** upstream source
directly:

```
grep -rhoE '_\("([^"\\]|\\.)*"\)' src data/blueprints | sed -E 's/^_\("//; s/"\)$//' | sort -u   # 41 msgids
grep -rhoE 'C_\("[^"]*", "([^"\\]|\\.)*"\)' data/blueprints                                      # 14 msgctxt msgids ("shortcut window")
```

against the port's `po/sudokugame.pot`. With the fix above applied, the
previously-dropped two strings now round-trip; nothing else regressed.

## Everything else re-checked this round

- `po/LINGUAS` (`de`, `fa`, `nl`, `vi`, `zh`) still matches the five `.po`
  files present.
- `test/drive_translations.rb` re-run directly this round: all 9 checks `ok`,
  `DRIVE OK` — main-menu/new-game button labels, home/pencil tooltips, the
  difficulty-label map, the shortcuts-dialog section title in context
  ("shortcut window"), and the untranslated-string English fallback
  (`FinishedPage::VICTORY_MESSAGE`) all round-trip through German.
- `Sudoku::ShortcutsDialog::SECTIONS` still wraps every title through
  `p_("shortcut window", ...)`, matching every `C_("shortcut window", ...)`
  call in `data/blueprints/shortcuts-dialog.blp` 1:1 by string.
- `po/POTFILES` lists the port's own `lib/sudoku/*.rb` paths (not upstream's
  stale list), confirmed again by reading the file — the port's own `rake
  pot` task is not affected by upstream's `POTFILES` being out of date.

## Not checked this round (unchanged from last round — still an honest gap, not a claim)

- A byte-for-byte diff of each language's **translated** strings (`msgstr`)
  against upstream's corresponding `.po` for fa/nl/vi/zh. Only German is
  spot-checked, by `test/drive_translations.rb`. The *keys* (msgids) are now
  fully censused and confirmed equal on both sides; the *translated values*
  for three of the five languages were not read this round either.

## Verdict

Clean on the msgid-survival axis this round was asked to check: every
upstream-marked string (41 simple + 14 context-keyed) has a surviving msgid
in `po/sudokugame.pot` and all five `.po` files, including the two that were
missing last round and are now confirmed fixed by direct inspection of both
the source fix and the regenerated catalogues. The one residual gap
(fa/nl/vi/zh `msgstr` values not spot-checked) is named, not hidden, and was
also named last round — it has not grown or shrunk.
