# Translation parity — Sudoku-rb

| | |
|---|---|
| Upstream | `main` @ `2be119d` |
| Port | `ruby` @ `46c2887` |
| Languages | de, fa, nl, vi, zh — both sides, `po/LINGUAS` matches |
| Catalogue mechanism | port reads `.po` directly at runtime (`lib/sudoku/translations.rb`); no `.mo` build step |

## Unchanged from the last round, re-verified rather than re-asserted

Neither `po/*`, `lib/sudoku/translations.rb`, `lib/sudoku/help_dialog.rb`,
nor `lib/sudoku/shortcuts_dialog.rb` were touched by `69463f2` or `46c2887`
(confirmed: `git show 46c2887 --stat` touches only `spec/log_utils_spec.rb`
and `test/drive_game.rb`). So this round re-ran the checks rather than
re-deriving the census from zero:

```
nix develop --command xvfb-run -a ruby test/drive_translations.rb
# ok   catalogue loaded: de
# ok   main menu button: Spiel Fortsetzen
# ok   new game button: Neues Spiel
# ok   home button tooltip: Zurück zum Hauptmenü
# ok   pencil button tooltip: Bleistiftmodus umschalten
# ok   difficulty label: Leicht
# ok   dialog difficulty row: Leicht
# ok   shortcut section in context: Spiel
# ok   untranslated message falls back: Puzzle Complete!
# DRIVE OK
```

9 of 9 `ok`, matching the 9 of this round's 59-check runtime gate that belong
to the translation driver (50 + 9 = 59).

- `grep -n "board is a 9"` / `"Casual Mode in Preferences"` against
  `po/sudokugame.pot` and all five `.po` files: both previously-missing
  msgids remain present (re-checked, unchanged).
- `po/LINGUAS` (`de, fa, nl, vi, zh`) still matches the five `.po` files
  present.
- `Sudoku::ShortcutsDialog::SECTIONS` still wraps every title through
  `p_("shortcut window", ...)`, matching every `C_("shortcut window", ...)`
  in `data/blueprints/shortcuts-dialog.blp` 1:1 by string.

## Not checked this round (unchanged gap, named every round rather than let drift)

- **A byte-for-byte diff of the translated `msgstr` values** for fa, nl, vi,
  zh against upstream's corresponding `.po` files. Only German is exercised
  by `test/drive_translations.rb`. The msgid keys are fully censused and
  equal on both sides (41 simple + 14 context-keyed strings); the actual
  translated text for three-quarters of the shipped languages has never been
  spot-checked by any automated step in this port, across three consecutive
  audit rounds.

## Verdict

Clean on the msgid-survival axis. Not clean overall: the `msgstr` gap for
fa/nl/vi/zh is real, has been named in every round so far, and still has no
check behind it of any kind.
