# Translation parity — Sudoku-rb

| | |
|---|---|
| Upstream | `main` @ `2be119d` |
| Port | `ruby` @ `e81851d` |
| Domain | `sudokugame` (matches on both sides) |
| Upstream messages | 75 distinct `(ctxt, id)` keys, 83 occurrences (6 reused), 0 plural, 14 with context |
| Ported | **55** |
| Gaps | **20** |
| Extra (untranslated port-only) | 0 |
| Kind mismatch | 0 |
| Uses mismatch | 1 (`"Sudoku"`: 4 upstream sites → 2 port sites — see below) |
| Languages | 5 `.po` files both sides (de, fa, nl, vi, zh), `po/LINGUAS` matches on both sides |
| `summary.parity` | **false** |

## This round ran the actual catalogue census; no prior round did

Every prior `translation-parity.md` verified specific known strings (the
shortcuts dialog, five hand-picked UI labels per language via
`test/drive_translations.rb`) and concluded "clean on the msgid-survival
axis." **None of them ever ran
`.claude/skills/translation-parity/scripts/catalogue.rb` against the whole
upstream tree.** Doing that this round is what found the gap:

```sh
ruby .claude/skills/translation-parity/scripts/catalogue.rb <upstream> --role upstream > up-cat.yaml
ruby .claude/skills/translation-parity/scripts/catalogue.rb .          --role port     > port-cat.yaml
ruby .claude/skills/translation-parity/scripts/catalogue.rb --compare up-cat.yaml port-cat.yaml
```

```yaml
summary:
  ported: 55
  gaps: 20
  extra: 0
  kind_mismatch: 0
  uses_mismatch: 1
  domain_matches: true
  parity: false
```

## The 20 gaps, all from two files with no port counterpart

Every one of the 20 gap messages comes from
`data/io.github.sepehr_rs.Sudoku.metainfo.xml.in` or
`data/io.github.sepehr_rs.Sudoku.desktop.in` — the two files
`component-identification.md` found this round have **no port file at all**.
These are not reworded or retyped strings; they are messages the port has
nowhere to put, because the component they belong to was never built:

| # | msgid | Upstream site | Text still owed |
|---|---|---|---|
| 1 | `Solve Sudoku puzzles` | `data/io.github.sepehr_rs.Sudoku.desktop.in:3` | `Solve Sudoku puzzles` |
| 2 | `Sudoku is a puzzle app that lets you solve classic number-placement challenges. It features a clean, distraction-free design with a simple interface to keep you focused and engaged.` | metainfo `<summary>`/`<p>` | same |
| 3 | `Features:` | metainfo | same |
| 4 | `Highlight active row and cell to improve focus and ease of play` | metainfo `<li>` | same |
| 5 | `Conflict highlighting to help identify mistakes, ideal for beginners` | metainfo `<li>` | same |
| 6 | `Keyboard shortcuts for quick access to all functions` | metainfo `<li>` | same |
| 7 | `Save and load games seamlessly to continue your progress anytime` | metainfo `<li>` | same |
| 8 | `Modern GTK4 and libadwaita interface` | metainfo `<li>` | same |
| 9 | `Suitable for all skill levels, from beginners to experts` | metainfo `<li>` | same |
| 10 | `Solve puzzles in style` | metainfo `<caption>` | same |
| 11 | `Sudoku in light mode` | metainfo `<caption>` | same |
| 12 | `Sudoku in dark mode` | metainfo `<caption>` | same |
| 13 | `Sudoku landing page in light mode` | metainfo `<caption>` | same |
| 14 | `Sudoku landing page in dark mode` | metainfo `<caption>` | same |
| 15 | `SepehrRS` | metainfo `<name>` (developer) | same |
| 16 | `game` | metainfo `<keywords>` | same |
| 17 | `logic` | metainfo `<keywords>` | same |
| 18 | `numbers` | metainfo `<keywords>` | same |
| 19 | `puzzle` | metainfo `<keywords>` | same |
| 20 | `sudoku` | metainfo `<keywords>` | same |

Each row's state is `gap` until `data/` gains the two files
`component-parity.md` names as missing (or their content, under
`sudokugame`'s domain, is ported into whatever file replaces them) and these
20 msgids appear verbatim in the port.

## `uses_mismatch`: `"Sudoku"` (4 → 2)

`"Sudoku"` itself is `ported` — the key is in the port's catalogue — but used
4 times upstream (`data/blueprints/window.blp:9,19`,
`data/io.github.sepehr_rs.Sudoku.desktop.in:2` (the desktop entry's `Name=`),
metainfo `<name>`) against 2 in the port (`lib/sudoku/window.rb:68,234`). The
two missing sites are the same two missing files — not a separate finding,
just the same gap showing up on the occurrence axis too. Per this skill's own
rule, this is **not** counted against `parity` (it is a component question),
but it is reported because it is real.

## Everything that was already correct, re-verified rather than re-asserted

- `po/LINGUAS` (`de, fa, nl, vi, zh`) matches the five `.po` files present on
  both sides — `diff <(ls up/po/*.po | xargs -n1 basename) <(ls po/*.po | xargs -n1 basename)` is empty.
- The 55 ported messages are byte-identical keys, confirmed by the generated
  catalogue diff, not by grepping for a handful of known strings.
- `test/drive_translations.rb` (extended this round, see `component-parity.md`)
  spot-checks **real translated text**, not just key presence, in **all
  five** shipped languages (previously only German), re-run directly this
  round: `DRIVE OK` × 5, 45 `ok` lines total.
- `Sudoku::ShortcutsDialog::SECTIONS` still wraps every title through
  `p_("shortcut window", ...)`, matching every `C_("shortcut window", ...)`
  in `data/blueprints/shortcuts-dialog.blp` 1:1 by string — all 14
  context-keyed messages.
- `domain_matches: true` — the port's `lib/sudoku/translations.rb` reads the
  same `sudokugame` domain upstream's `meson.build` configures, from the
  same `po/*.po` files, copied across unchanged.
- The two `!unresolved` rows the census flags in
  `lib/sudoku/translations.rb:184,186` are the `_()`/`p_()` method
  *definitions* themselves, not calls with a dynamic argument — read and
  confirmed as scanner noise, not a real unresolved message.

## Verdict

**Not clean.** 55 of 75 upstream messages are ported, byte-identical, in all
5 languages the port already carries — real, verified work, not an
assertion. But every prior round's "clean on the msgid-survival axis"
verdict was wrong, because it was reached without ever running the
catalogue census against upstream's whole message surface (code +
blueprints + `.desktop.in` + metainfo + gschema). The 20-message gap is a
direct consequence of the component gap `component-parity.md` names this
round (no `.desktop.in`, no metainfo file in the port) and will not close
until those files, or their content, exist in the port.
