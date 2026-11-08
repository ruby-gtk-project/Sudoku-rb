# Component parity — Sudoku-rb

| | |
|---|---|
| Upstream | `main` @ `2be119d` |
| Port | `ruby` @ `e81851d` |
| Runtime gate, re-run directly this round | `test/drive_game.rb` → `45 of 45 checks passed`, `DRIVE OK`. `test/drive_translations.rb` → `DRIVE OK` for de, fa, nl, vi, zh (5 × 9 = 45 `ok` lines, all 5 languages spot-checked against real translated strings, not just key presence). `rspec` → `140 examples, 0 failures`. |

## Three previously-named gaps, re-verified closed this round

| Named gap (prior rounds) | This round | Verified by |
|---|---|---|
| `style.rb` — zero coverage of any kind | **Closed.** `spec/style_spec.rb` (315 lines) parses both `Sudoku::Style::LIGHT`/`DARK` and upstream's `data/style.css`/`data/style-dark.css` into selector→declaration maps and diffs them selector-by-selector, plus exercises `.light_provider`/`.dark_provider`/`.install` against a real `Gtk::CssProvider` | Re-read the spec file; independently re-diffed the two stylesheets byte-for-byte myself (see below) rather than trusting the spec's own diff logic |
| RTL mirroring and the ghost-click guard in `input_handler.rb` untested | **Closed.** `spec/input_handler_spec.rb` adds a `ghost click` describe block (left-click-held-with-right-button, right-held-with-left, middle-click-ignored) and an `RTL direction handling` block that injects `direction: -> { Gtk::TextDirection::RTL }` and asserts Left/Right mirror while Up/Down do not | Re-read the spec; both blocks present and exercised in the 140-example run |
| Translated `msgstr` values for fa/nl/vi/zh never spot-checked | **Closed.** `test/drive_translations.rb` now drives all five catalogues (not just German), asserting on seven real translated strings per language (menu button, new-game button, tooltip text, difficulty label, dialog row, shortcut section, untranslated-message fallback) | Re-ran it directly; 45 `ok` lines, 9 per language × 5 |

I independently re-diffed the stylesheets rather than trust the new spec's
own comparison logic:

```sh
nix develop --command xvfb-run -a ruby -e '
require "./lib/sudoku/style"
File.write("light.css", Sudoku::Style::LIGHT)
File.write("dark.css",  Sudoku::Style::DARK)'
diff data/style.css light.css        # one indentation line (tab vs 4 spaces), one blank line, trailing newline only
diff data/style-dark.css dark.css    # trailing newline only
```

Both are a correspondence (whitespace-only), not a gap. CSS parity for the
cell/grid/popover stylesheet is real, not an assertion I took on the spec's
word.

## New finding this round: upstream's App metadata has no port component at all

Widening `component-identification` to upstream's whole `data/` tree (not
just `data/blueprints/`) found two upstream files with no port counterpart:

### `data/io.github.sepehr_rs.Sudoku.metainfo.xml.in` → — (missing)

Upstream's `src/application.py#on_about_action` reads the **installed**
metainfo file at runtime, extracts the `<release>` entry whose `version`
matches the running app, and feeds its `<description>` into
`Adw.AboutDialog(release_notes=...)` — a "What's New" section in the About
dialog (`src/application.py:89-125`).

The port's `about_dialog` (`lib/sudoku/application.rb:83-95`) builds the same
`Adwaita::AboutDialog` with the same name/icon/developers/copyright/license/
issue URL, but never sets `release_notes`, and there is no metainfo file in
the tree for any such lookup to read even if the code existed. This is a
**gap**: a real section of the About dialog (release notes for the running
version) that the port cannot show under any circumstance, because neither
the data nor the code path exists.

| Widget | Upstream | Port | Verdict |
|---|---|---|---|
| `Adw.AboutDialog` | built with `release_notes=` populated from the installed metainfo | built without `release_notes` | **gap** |

### `data/io.github.sepehr_rs.Sudoku.desktop.in` → — (missing)

No desktop entry file exists in the port tree at all — no launcher name,
`GenericName`, `Comment`, `Keywords`, or `Icon` key for a system to use for
search/launch integration (`data/io.github.sepehr_rs.Sudoku.desktop.in`
upstream). This is packaging metadata rather than a widget, but it is a real
upstream component with user-visible text (`Comment=Solve Sudoku puzzles`)
that the port has nowhere to put. **Gap.**

### `src/application.py#generate_debug_info` vs `lib/sudoku/application.rb#debug_info`

A smaller, related finding while reading the same file on both sides:
upstream's debug info includes a `Dist: <PRETTY_NAME>` line on Linux
(`platform.freedesktop_os_release()['PRETTY_NAME']`); the port's `debug_info`
(`lib/sudoku/application.rb:99-110`) has no equivalent line. Minor, but it is
a line of the Troubleshooting report a Linux user sees upstream and does not
see in the port. **Gap**, narrow.

## Everything else checked this round (read, not re-scanned, since unchanged)

- `GridSolver`/`PuzzleGenerator` (`lib/sudoku/generator.rb`) is a from-scratch
  reimplementation of the behaviour the upstream `sudoku` PyPI package
  provides (there is no Ruby package to port), including the forked-worker
  timeout upstream gets from `multiprocessing` (`generate_in_worker`,
  `collect_worker_result` mirror `CoreSudokuGenerator.generate`/
  `_generate_worker`/the `TimeoutError`/`RuntimeError` pair). Correspondence,
  not a gap — read in full this round, not assumed from the file's own
  comment.
- `shortcuts_dialog.rb` matches `data/blueprints/shortcuts-dialog.blp`
  exactly: 4 sections, 10 items, same titles, same accelerators, each
  wrapped in the same `p_("shortcut window", ...)` / `C_("shortcut
  window", ...)` context both sides use.
- `preferences_page.rb`'s `VariantPreferencesPage`/`GeneralPreferencesPage`
  build their `Adw.ActionRow`/`Gtk.Switch`/`Adw.SpinRow` rows in a loop over
  the same preference dicts upstream loops over — a shared-factory pattern
  (`component-identification`'s Step 4 caveat), not the 3-ActionRow-vs-1 gap
  the raw scan count suggested before reading the file.
- `game_setup_dialog.rb`'s two `Gtk.ListBox`es (`variant_list`,
  `difficulty_list`) both come from one `boxed_list` factory method, called
  twice — again a shared factory, not a missing ListBox.
- `CellFeedback` in `sudoku_cell.rb` is the port of `src/shared/utils.py`'s
  `schedule_feedback_clear`/`clear_cell_feedback` (it uses
  `add_css_class`/`remove_css_class` where upstream calls
  `get_style_context().add_class`/`remove_class` — same behaviour, newer
  GTK4 API on both ends since upstream's own style-context calls are the
  older spelling of the same operation).

## Verdict

**Not clean.** Three gaps named in prior rounds are genuinely closed this
round, each independently re-verified rather than taken from a commit
message. Two new, real gaps were found by widening the identification scan
beyond `src/`/`data/blueprints/` to upstream's whole `data/` directory: the
port has no AppStream metainfo file and no `.desktop` file, which means the
About dialog's release-notes section can never render (the lookup has
nothing to read even if it were built), and the system has no desktop-entry
metadata at all. A third, narrower gap (`debug_info` missing the Linux
distribution line) was found reading the same file.
