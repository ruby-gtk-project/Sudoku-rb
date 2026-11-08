# Component identification — Sudoku-rb

| | |
|---|---|
| Upstream | `main` @ `2be119d` (unchanged across four consecutive rounds) |
| Port | `ruby` @ `e81851d` |

## This round widened the scan, and that is what found the gap

Every prior round's identification step walked `origin/main:src/` and
`origin/main:data/blueprints/` for `.py`/`.blp` files and matched each one
against a `lib/sudoku/*.rb` file. That method is structurally blind to any
upstream file that is not source or blueprint — and upstream ships three such
files that the port has never inventoried against anything:

```
git ls-tree -r --name-only origin/main -- data | grep -v '\.(blp|css|svg|png)$'
  data/io.github.sepehr_rs.Sudoku.desktop.in
  data/io.github.sepehr_rs.Sudoku.gschema.xml
  data/io.github.sepehr_rs.Sudoku.metainfo.xml.in
  data/sudokugame.gresource.xml.in
```

| Upstream file | Port counterpart | Exists? |
|---|---|---|
| `data/io.github.sepehr_rs.Sudoku.desktop.in` | — | **No.** No `.desktop`/`.desktop.in` file anywhere in the port tree. |
| `data/io.github.sepehr_rs.Sudoku.metainfo.xml.in` | — | **No.** No AppStream metainfo file anywhere in the port tree. |
| `data/io.github.sepehr_rs.Sudoku.gschema.xml` | — (empty schema upstream too: `<schema id="..."/>` defines zero keys) | Confirmed not a gap — upstream itself keeps no GSettings keys; state lives in the JSON files `persistence.rb`/`preferences.rb` already port. |
| `data/sudokugame.gresource.xml.in` | — (no gresource bundle; the port loads icons/CSS/illustrations directly from disk, per `Sudoku.data_path`) | Correspondence, not a gap — see `component-parity.md`. |

The desktop file and the metainfo file are the two real misses, and they are
not cosmetic: the metainfo file is what upstream's `on_about_action` reads at
runtime (from the system data dirs) to populate the About dialog's release
notes, and both files are gettext sources — `po/POTFILES` lists them, and
`translation-parity.md`'s fresh census (this round, not any prior one) finds
**20 upstream messages that live in no file the port has**, all of them from
these two files.

## File-level census of `src/` and `data/blueprints/`, re-run this round

```sh
.claude/skills/component-identification/scripts/component-scan.sh /tmp/.../sudoku-upstream
.claude/skills/component-identification/scripts/component-scan.sh .
```

- `ls lib/sudoku/*.rb` → 25 files. Every `src/**/*.py` and `data/blueprints/*.blp`
  file maps to one or more of them (the per-unit mapping is in
  `component-parity.md`).
- No `src/` or `data/blueprints/` file was added or removed on `origin/main`
  since the last round — `2be119d` is unchanged.
- No new `lib/sudoku/*.rb` file was added since the last round
  (`82294ee`/`e81851d` added `spec/style_spec.rb`, extended
  `spec/input_handler_spec.rb` and `test/drive_translations.rb` — test/driver
  coverage for units that already had a port file, not new units).

## Finding

File existence against `src/` and `data/blueprints/` has been stable for four
rounds: every upstream window, page, dialog, widget group and model file in
those two directories has a corresponding port file. **That stability is why
the real miss went unnoticed for four rounds** — the method used to establish
it never looked at `data/*.desktop.in`, `data/*.metainfo.xml.in` or
`data/*.gresource.xml.in`, so two real missing components were outside the
set this check could ever find. The identification axis is therefore **not
clean**: two upstream data files (`.desktop.in`, `.metainfo.xml.in`) have no
port counterpart, found this round by widening the scan to upstream's whole
`data/` tree instead of only its blueprints.
