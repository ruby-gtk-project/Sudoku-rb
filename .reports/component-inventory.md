# Sudoku — upstream component inventory

Upstream: `origin/main` (Python / PyGObject / blueprint, app id
`io.github.sepehr_rs.Sudoku`). Port: the `ruby` branch of this repo.

Read with the `component-identification` skill: a component is a widget *plus*
its CSS classes, its signals, the actions it installs or targets, and the file
that owns it. Upstream splits most components across a `.py` class and its
`.blp` template, so each section below unions both halves.

The port is a gem (`sudoku-rb`, `module Sudoku`), so port files live at
`lib/sudoku/<thing>.rb`, not `lib/<thing>.rb`.

## Status summary

Nothing user-facing is ported yet. `lib/sudoku/application.rb` holds a
placeholder `Adwaita::StatusPage` reading "The Ruby port has not been written
yet"; `lib/sudoku.rb` requires it and `exe/sudoku` runs it. Every component
below is **missing** except the application shell, which exists as a stub.

Totals: 13 components, 1 partially present (the application class), 12 absent.

---

## src/application.py — the application class

Holds the app actions, the accelerator table, the About dialog and the
entry points for How to Play and the shortcuts window. Not a widget.

| Item | Detail |
|---|---|
| Base | `Adw.Application` (app id `io.github.sepehr_rs.Sudoku`, `FLAGS_NONE`) |
| App actions | `app.quit` (`<primary>q`, `<primary>w`), `app.about`, `app.how_to_play` (`F1`), `app.shortcuts` (`<Ctrl>question`) |
| Accelerators for window actions | `win.pencil-toggled` → `p`; `win.back-to-menu` → `<Ctrl>m`; `win.show-primary-menu` → `F10`; `win.show-preferences` → `<primary>comma`; `win.auto-pencil-marks` → `<Shift>p` |
| Widget | `Adw.AboutDialog` — application name, icon, developer "Sepehr", developers `["Sepehr","Revisto"]`, copyright, `Gtk.License.GPL_3_0`, `issue_url`, `debug_info`, `release_notes` scraped from the installed metainfo XML |
| Signals | `activate` → raise or create `SudokuWindow` |
| Notes | Actions are built in a loop from a dict, so the names are not literals in the source — all five app action names are listed above. `generate_debug_info` reports system, distro, Python, GTK, Adwaita and PyGObject versions plus captured logs; the Ruby port must substitute `Gtk::Version` (there is no `Gtk::VERSION`) and its own runtime facts. `Adwaita::Application` is broken in the Ruby bindings — the port keeps `Gtk::Application` with an `Adwaita::ApplicationWindow`, as the existing stub already does. |

**Port:** `lib/sudoku/application.rb` — **exists as a stub**, has the
`Gtk::Application` + window shell and none of the actions, accelerators or the
About dialog.

Repeaters: none. Conditional: the distro line only on Linux; release notes only
when a metainfo file for the running version is installed.

---

## src/window.py + data/blueprints/window.blp — the main window

One `Adw.ApplicationWindow` carrying the header bar, the page `Gtk.Stack`
(main menu, game board, finished, game over, loading), the primary menu, the
breakpoints and the window actions.

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adw.ApplicationWindow` | 1 | `sudoku-main-window` | — | title "Sudoku", 710×810 default, 360×420 minimum |
| `Adw.ToolbarView` | 1 | — | — | top bar + content |
| `Adw.HeaderBar` | 1 | — | — | |
| `Adw.WindowTitle` | 1 | — | — | `sudoku_window_title`; subtitle is rewritten constantly: `""`, `"<Variant> • <Difficulty>"`, that plus `" • Mistakes: N"` when the mistake counter is on, or "Pencil Mode • Note possible numbers" |
| `Gtk.Button` | 1 | — | — | `home_button`, start of header, icon `back-symbolic`, tooltip "Back to Main Menu", `action-name: win.back-to-menu`, visibility toggled per page |
| `Gtk.MenuButton` | 1 | — | — | `primary_menu_button`, end, icon `open-menu-symbolic`, tooltip "Menu", `popup()`-ed by `win.show-primary-menu`, menu model rebuilt per page |
| `Gtk.ToggleButton` | 1 | — | `toggled` → `_on_pencil_toggled_button` | `pencil_toggle_button`, end, icon `document-edit-symbolic`, tooltip "Toggle Pencil Mode", visible only on game pages |
| `Adw.BreakpointBin` | 1 | `large`, `compact-mode`, `small-mode` (all dynamic) | — | `bp_bin`; the three classes are added/removed by the breakpoints below |
| `Adw.Breakpoint` | 3 | — | `apply`, `unapply` → `_apply_mode` | `min-width: 800px and min-height: 800px` → `large`; `max-width: 650px or max-height:700px` → `compact-mode`; `max-width: 550px or max-height:550px` → `small-mode`. Compact and small also call `controller.apply_compact_mode` |
| `Gtk.Stack` | 1 | — | `notify::visible-child` → `on_stack_page_changed` | crossfade, 300 ms; 6 children |
| `Gtk.ScrolledWindow` | 2 | — | — | `main_menu_box` (both policies `never`) and `game_scrolled_window` (both `automatic`) |
| `Adw.StatusPage` | 1 | — | — | `main_menu_status_page`, hosts the menu box |
| `Gtk.Box` | 2 | — | — | `menu_box` (vertical, spacing 12, centred) and `grid_container` (vertical, expanding; the board is appended here) |
| `Gtk.Image` | 1 | `icon-dropshadow` | — | app icon, 256 px, 65 px bottom margin |
| `Gtk.Button` | 2 | `pill` | `clicked` → `on_continue_clicked` / `on_new_game_clicked` | "Continue Game" (visible only when a save exists, tooltip "Continue Saved Game") and "New Game" (tooltip "Start a New Game"); both `use-underline` |
| `Gtk.GestureClick` (controller) | 1 | — | `pressed` → `_on_window_pressed` | button 0, CAPTURE phase; a left click outside the grid allocation calls `controller.on_grid_unfocus` |
| Child components | 3 | — | — | `$FinishedPage`, `$GameOverPage`, `$LoadingScreen` as stack pages (own sections) |

**Window actions** (built in a loop, so none is a literal in the scan):
`win.show-primary-menu`, `win.back-to-menu`, `win.pencil-toggled`,
`win.show-preferences`, `win.auto-pencil-marks`. `show-preferences`,
`auto-pencil-marks`, `show-primary-menu` are enabled only on game pages;
`back-to-menu` is disabled on the main menu and the loading screen.

**Primary menu** (`Gio.Menu`, one section, rebuilt by
`_build_primary_menu(show_game_actions)`): "Keyboard Shortcuts" →
`app.shortcuts`; then, on game pages only, "Preferences" →
`win.show-preferences` and "Auto Pencil Marks" → `win.auto-pencil-marks`; then
"How To Play" → `app.how_to_play` and "About Sudoku" → `app.about`.

**Port:** `lib/sudoku/window.rb` — **missing**.

Repeaters: the stack's pages are fixed; the five window actions and the three
breakpoints are loop-built. Conditional: `continue_button` visibility on
`has_saved_game()`; header-bar buttons and menu items per visible page; the
difficulty label map `{0.2 Easy, 0.5 Medium, 0.7 Hard, 0.9 Extreme}`.

---

## src/screens/game_setup_dialog.py — the New Game dialog

Built entirely in source; no blueprint.

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adw.Dialog` | 1 | — | `realize` → focus the start button | title "New Game", 410×490 |
| `Adw.ToolbarView` | 1 | — | — | |
| `Adw.HeaderBar` | 1 | — | — | |
| `Gtk.ScrolledWindow` | 1 | — | — | policy NEVER / AUTOMATIC |
| `Gtk.Box` | 1 | — | — | vertical, spacing 16, 12 px margins |
| `Gtk.ListBox` | 2 | `boxed-list` | — | variant list and difficulty list, selection mode NONE |
| `Adw.ActionRow` | 6 | — | `activated` → activate its check button | 2 variants + 4 difficulties; each has `activatable_widget` set to its check button |
| `Gtk.CheckButton` | 6 | `radio` | `toggled` → `_on_radio_toggled` | grouped per list; "Classic Sudoku"/"Diagonal Sudoku" (default classic) and "Easy"/"Medium"/"Hard"/"Extreme" (default Easy = 0.2) |
| `Gtk.Button` | 1 | `pill`, `suggested-action` | `clicked` → `_on_confirm_clicked` | "Start Game", centred; calls back with (variant, difficulty) and closes |

**Port:** `lib/sudoku/game_setup_dialog.rb` — **missing**.

Repeaters: `_create_radio_list` is a shared factory called twice and producing
6 rows and 6 check buttons — the scan sees one of each.

---

## src/screens/preferences_dialog.py — the Preferences dialog

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adw.PreferencesDialog` | 1 | — | — | title "Preferences", search disabled |
| `Adw.PreferencesPage` | 1 | — | — | holds both groups |

Reached by `win.show-preferences` (`<primary>comma` or the primary menu), only
when a controller exists. Its `auto_save_function` saves preferences, saves the
board and refreshes the window subtitle.

**Port:** `lib/sudoku/preferences_dialog.rb` — **missing**.

---

## src/screens/preferences_page.py — the two preferences groups

Two `Adw.PreferencesGroup` subclasses, both generated from dicts.

### `GeneralPreferencesPage` (title "General")

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adw.PreferencesGroup` | 1 | — | — | |
| `Adw.ActionRow` | 8 | — | — | 7 toggle rows + 1 counted toggle row; title is the key Title-Cased, subtitle is the key's tooltip when non-empty; `activatable_widget` is the switch |
| `Gtk.Switch` | 8 | — | `notify::active` → `_on_bool_changed` / `_on_counted_toggle_changed` | valign CENTER |
| `Adw.SpinRow` | 1 | — | `notify::value` → `_on_count_changed` | `new_with_range(1, 20, 1)`, title "Mistake limit", sensitive only while the mistake-limit switch is on |

Toggle keys and defaults (from `src/core/preferences.py`): `casual_mode` on
("Highlight when input does not match the correct solution"),
`prevent_conflicting_pencil_notes` off, `highlight_row` on, `highlight_column`
on, `auto_remove_notes` off ("Automatically remove pencil notes after a correct
entry"), `show_remaining_valid_inputs` off ("View the possible places left for
each number"), `show_popover` on ("Show popover when clicking on a cell").
Counted: `mistake_limit` — disabled, count 3 ("End the game or warn after a set
number of mistakes").

### `VariantPreferencesPage` (title = the variant's name)

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adw.PreferencesGroup` | 1 | — | — | title "Classic Sudoku" or "Diagonal Sudoku" |
| `Adw.ActionRow` | 2–3 | — | — | one per variant key |
| `Gtk.Switch` | 2–3 | — | `notify::active` → `on_toggle_changed` | |

Variant keys: classic → `highlight_block`, `highlight_related_cells` (both on);
diagonal adds `highlight_diagonals` (on).

**Port:** `lib/sudoku/preferences_page.rb` — **missing**.

Repeaters: both groups build every row in a loop over a dict — the row counts
above are the live counts, not scan counts.

---

## src/screens/help_dialog.py + data/blueprints/how-to-play-dialog.blp — How to Play

Six-page carousel reached by `app.how_to_play` / `F1` / the primary menu.

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adw.Dialog` | 1 | `how-to-play-dialog` | — | 600×500 |
| `Adw.ToolbarView` | 1 | — | — | |
| `Adw.HeaderBar` | 1 | — | — | title widget is the dots |
| `Adw.CarouselIndicatorDots` | 1 | — | — | bound to the carousel |
| `Gtk.Overlay` | 1 | — | — | hosts the two nav buttons |
| `Adw.Clamp` | 1 | — | — | max 600, tightening 400 |
| `Adw.Carousel` | 1 | — | `page-changed` → `on_page_changed` | long swipes and scroll wheel allowed, spacing 40 |
| `Gtk.Box` | 7 | — | — | one wrapper per page plus the clamp's child |
| `Gtk.AspectFrame` | 6 | — | — | ratio 1.0, centred |
| `Gtk.Picture` | 6 | — | — | resources `basics.svg`, `rows-and-columns.svg`, `blocks.svg`, `casual.svg`, `mistake.svg`, `pencil-mode.svg` |
| `Adw.StatusPage` | 6 | — | — | "The Basics", "Rows & Columns", "Blocks Matter", "Casual Mode", "Mistakes Happen", "Make Notes", each with its description paragraph; all `can-focus` |
| `Gtk.Button` | 2 | `circular` | `clicked` → `on_prev_clicked` / `on_next_clicked` | `prev` (`go-previous-symbolic`, tooltip "Previous", starts insensitive) and `next` (`go-next-symbolic`, tooltip "Next"); sensitivity recomputed from carousel position |
| `Gtk.EventControllerKey` (controller) | 1 | — | `key-pressed` → `on_key_pressed` | Left/Right paginate, swapped under RTL |

**Port:** `lib/sudoku/help_dialog.rb` — **missing**.

Repeaters: the six carousel pages are literal in the blueprint, not looped.

---

## data/blueprints/shortcuts-dialog.blp — the shortcuts window

A standalone blueprint object (`Adw.ShortcutsDialog shortcuts_dialog`) with no
backing source class; `app.shortcuts` loads it from the GResource with
`Gtk.Builder` and presents it.

| Widget | × | Notes |
|---|---:|---|
| `Adw.ShortcutsDialog` | 1 | |
| `Adw.ShortcutsSection` | 4 | "Game", "Pencil", "Input", "General" (all with the `shortcut window` message context) |
| `Adw.ShortcutsItem` | 10 | Game: Move Between Cells `Up Down Left Right`, Jump Between Blocks `<Primary>Up Down Left Right`. Pencil: Pencil Mode `P`, Auto Pencil Marks `<Shift>P`, Place Pencil Mark `<Primary>1...9`. Input: Open Number Pop-Up `Return`. General: Show Shortcuts `<Primary>question`, Back to Main Menu `<Primary>M`, How to Play `F1`, Quit `<Primary>Q <Primary>W` |

**Port:** `lib/sudoku/shortcuts_dialog.rb` — **missing**.

---

## src/screens/finished_page.py + data/blueprints/finished-page.blp — the win page

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Gtk.Box` (template root) | 1 | — | `map` → `_on_map` | stack page; 30 px bottom margin |
| `Gtk.Box` | 2 | — | — | vertical wrappers, spacing 12 |
| `Adw.Clamp` | 1 | — | — | max 1200, tightening 300 |
| `Gtk.Picture` | 1 | — | — | `picture_contain`; `content-fit: contain`, `can-shrink`, 60 px bottom margin; resource is `puzzle-complete-celebration-dark.svg` or `-light.svg` |
| `Gtk.Label` | 1 | `title-1` | — | `finished_label`, wrapped and centred, text "Puzzle Complete!" |
| `Adw.StyleManager` (not a widget) | 1 | — | `notify::dark` → `_update_picture` | swaps the illustration with the system theme |

**Port:** `lib/sudoku/finished_page.rb` — **missing**.

Conditional: the dark/light illustration choice.

---

## src/screens/game_over_page.py + data/blueprints/game-over-page.blp — the loss page

Structurally identical to the finished page: `Gtk.Box` root (`map` →
`_on_map`), two boxes, `Adw.Clamp` (1200/300), one `Gtk.Picture`
(`puzzle-game-over.svg`, no dark variant) and one `Gtk.Label` with `title-1`
reading "Game Over!". Shown when the mistake count exceeds the configured
limit.

**Port:** `lib/sudoku/game_over_page.rb` — **missing**.

---

## src/screens/loading_screen.py + data/blueprints/loading-screen.blp — the loading page

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Gtk.Box` (template root) | 1 | — | — | stack page; 30 px bottom margin |
| `Adw.Clamp` | 1 | — | — | max 1200, tightening 300 |
| `Gtk.Box` | 1 | — | — | vertical, spacing 24 |
| `Adw.Spinner` | 1 | — | — | 48×48, centred |

Shown while the generator thread runs; the source class is empty.

**Port:** `lib/sudoku/loading_screen.rb` — **missing**.

---

## src/shared/sudoku_cell.py — one cell of the board

`SudokuCell(Gtk.Button)` plus its two helper classes
(`SudokuCellUIManagement`, `SudokuCellNotesManagement`). 81 of these exist per
game.

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Gtk.Button` (the cell) | 1 per cell | `sudoku-cell-button`, plus exactly one of `clue-cell` / `entry-cell`, plus dynamically `highlight`, `wrong`, `correct`, `conflict`, `toggle-active` | `clicked` → `_on_clicked` (stops the emission when not editable) | focusable; size request 40×40, or 10×10 in compact mode; tooltip set to "Correct Entry" / "Wrong Entry" on feedback |
| `Gtk.Overlay` | 1 per cell | — | — | main label with the notes grid overlaid, both FILL |
| `Gtk.Label` (value) | 1 per cell | — | — | centred, expanding |
| `Gtk.Grid` (notes) | 1 per cell | — | — | homogeneous 3×3, hidden while the cell has a value |
| `Gtk.Label` (note) | 0–9 per cell | `note-cell-label` | — | size request 12×12, or 8×8 compact |

Feedback classes are added and removed on a `GLib.timeout_add` (2000 ms for
pencil conflicts, 4000 ms otherwise) — see `src/shared/utils.py`
(`schedule_feedback_clear`, `clear_cell_feedback`).

**Port:** `lib/sudoku/sudoku_cell.rb` — **missing**.

Repeaters: the cell itself (81 per board) and its note labels (up to 9 per
cell). All five feedback classes are applied from variables, so none appears in
a scan of the source.

---

## src/shared/grid_manager.py — the board grid

Builds the widget tree the game is played on and appends it to the window's
`grid_container`.

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Gtk.AspectFrame` | 1 | — | — | ratio 1.0, `obey_child: false`, expanding and FILL |
| `Gtk.Grid` (parent) | 1 | widget name `sudoku-parent-grid` (styled by `#sudoku-parent-grid` in the CSS) | — | row/column spacing 10, 8 in compact mode; homogeneous |
| `Gtk.Grid` (block) | 9 | `sudoku-block` | — | spacing 4, 2 in compact mode; homogeneous |
| `Gtk.GestureClick` (controller) | 81 | — | `released` → `on_cell_clicked` | one per cell, button 0, CAPTURE phase |
| `Gtk.EventControllerKey` (controller) | 81 | — | `key-pressed` → `on_key_pressed(row, col)` | one per cell |
| `SudokuCell` | 81 | see above | — | attached into its block at its inner row/column |

**Port:** `lib/sudoku/grid_manager.rb` — **missing**.

Repeaters: the 9 blocks, the 81 cells and the 162 controllers are all built in
nested loops — the scan sees one of each. Rebuilding tears the old tree down
and cancels every pending feedback timeout.

---

## src/shared/popover_manager.py — the number-entry popover

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Gtk.Popover` | 1 | widget name `sudoku-popover` (styled by `#sudoku-popover button`) | `closed` → `_on_popover_closed` (restores focus to the cell via `GLib.idle_add`) | position BOTTOM, no arrow, parented on the parent grid, pointed at the cell's allocation with a `Gdk.Rectangle`; suppressed entirely when the `show_popover` preference is off |
| `Gtk.Grid` | 1 | — | — | row/column spacing 5, focusable and focus-grabbing |
| `Gtk.Button` (number) | 9 | — | `clicked` → `on_number_selected` | labels "1".."9", 40×40, laid out 3×3; insensitive when that number has 0 remaining placements |
| `Gtk.Overlay` + `Gtk.Label` | 0–9 | `corner-label` | — | remaining-count badge over a number button, only when the `show_remaining_valid_inputs` preference is on and the count > 0 |
| `Gtk.Box` | 1 | — | — | horizontal action row, spacing 5, spanning the grid's 4th row |
| `Gtk.Button` ("Clear") | 1 | — | `clicked` → `on_clear_selected` | height 40, expanding, tooltip "Clear Cell (Del/Backspace)" |
| `Gtk.Button` ("Done") | 0–1 | — | `clicked` → popdown | only in pencil mode or on a right-click; tooltip "Finish Editing Cell" |
| `Gtk.EventControllerKey` (controller) | 1 | — | `key-pressed` | 1–9 click the matching number button, Backspace/Delete click Clear |

**Port:** `lib/sudoku/popover_manager.rb` — **missing**.

Repeaters: the nine number buttons and their badges are loop-built.
Conditional: the badges, the insensitive state, and the Done button.

---

## src/shared/input_handler.py — keyboard and pointer translation

Not a widget, but it owns the controller factories and the whole key map, so
every board interaction is defined here.

| Item | Detail |
|---|---|
| Controllers produced | `Gtk.GestureClick` per cell (button 0, CAPTURE, `released`); `Gtk.EventControllerKey` per cell; `Gtk.EventControllerKey` for the popover grid |
| Keys | `1`–`9` and `KP_1`–`KP_9` fill; any Unicode digit 1–9 fills; `Ctrl`+digit writes a pencil mark; arrows move one cell, `Ctrl`+arrow jumps three; `Return`/`KP_Enter` opens the popover; `BackSpace` removes the last note or the value, `Delete`/`KP_Delete` clears the cell entirely |
| RTL | Left/Right are mirrored when the window direction is RTL |
| Pointer | Only buttons 1 and 3 act; right-click writes a pencil mark; a click arriving while the other button is held is discarded as a ghost click |

**Port:** `lib/sudoku/input_handler.rb` — **missing**.

---

## Non-UI upstream files the components depend on

These carry no widgets but the UI cannot be ported without them, and each wants
its own port file:

| Upstream | Port | What it is |
|---|---|---|
| `src/core/controller.py` | `lib/sudoku/controller.rb` | game lifecycle, highlighting, feedback, mistake limit, compact mode, win/lose transitions; owns the generator thread |
| `src/core/board.py` | `lib/sudoku/board.rb` | cells, inputs, notes, conflicts, auto pencil marks, remaining-valid-input counts |
| `src/core/generator.py` | `lib/sudoku/generator.rb` | puzzle generation by difficulty |
| `src/core/persistence.py` | `lib/sudoku/persistence.rb` | `board.json` and `preferences.json` under the user data dir, plus the legacy-format migrations |
| `src/core/preferences.py` | `lib/sudoku/preferences.rb` | preference defaults, tooltips and the `PreferencesManager` singleton |
| `src/core/constants.py` | folded into `lib/sudoku/board.rb` | |
| `src/variants/classic_sudoku/*`, `src/variants/diagonal_sudoku/*` | `lib/sudoku/classic_sudoku.rb`, `lib/sudoku/diagonal_sudoku.rb` | board/controller/generator/preferences per variant |
| `src/shared/utils.py` | folded into `lib/sudoku/sudoku_cell.rb` | CSS-class feedback timeouts |
| `src/log_utils.py` | `lib/sudoku/log_utils.rb` | the in-memory log buffer the About dialog's debug info shows |
| `data/style.css`, `data/style-dark.css` | `lib/sudoku/style.rb` (or a loaded asset) | defines `sudoku-main-window`, `icon-dropshadow`, `sudoku-cell-button`, `clue-cell`, `entry-cell`, `note-cell-label`, `corner-label`, `highlight`, `wrong`, `correct`, `conflict`, `toggle-active`, `#sudoku-parent-grid`, `#sudoku-popover`, and the `large` / `compact-mode` / `small-mode` variants of the cell and grid rules |
| `data/illustrations/*.svg`, `data/icons/**` | a port asset directory | 9 illustrations plus `back-symbolic` and `pencil-symbolic` |
| `po/*` | the port's own catalogue | 5 catalogues (de, fa, nl, vi, zh) |

---

## Blockers and decisions

1. **`sudoku-block` is applied but never defined.** `grid_manager.py` adds the
   class to every block grid; neither stylesheet declares it. The port should
   reproduce the class, not the (absent) styling.
2. **The GSettings schema is empty.** `data/io.github.sepehr_rs.Sudoku.gschema.xml`
   declares the schema id and no keys — all state is JSON under
   `GLib.get_user_data_dir()/sudokugame/`. Nothing to port on the settings axis.
3. **`po/POTFILES` is stale.** It lists `src/window.blp`,
   `src/gtk/finished-overlay.blp`, `src/gtk/shortcuts-overlay.blp`,
   `src/finished_overlay.py`, `src/game_manager.py` and
   `src/difficulty_selection_dialog.py`, none of which exist on `origin/main`,
   and omits every current screen. Translatable strings must be read from the
   sources and `po/sudokugame.pot`, not from POTFILES.
4. **`po/LINGUAS` omits `de`** although `po/de.po` is committed. Five
   catalogues exist; four are listed.
5. **Port path convention.** The task brief says `lib/<thing>.rb`, but this
   fork is a gem (`sudoku-rb`, `module Sudoku`, `lib/sudoku.rb` →
   `lib/sudoku/...`) and already has `lib/sudoku/application.rb`. This inventory
   uses `lib/sudoku/<thing>.rb` throughout.
6. **No window/dialog state is driven by GSettings**, so window size is not
   remembered upstream either — don't add it.
7. **`Adwaita::Application` is unusable in the Ruby bindings**, so the port
   cannot subclass it the way upstream subclasses `Adw.Application`; the app
   actions and accelerators must be installed on a `Gtk::Application`.
8. **`Adw.ShortcutsDialog` is recent libadwaita (1.8+).** Whether the
   installed Adwaita in the dev shell exposes it needs checking before
   `lib/sudoku/shortcuts_dialog.rb` is written; otherwise the section/item
   tree has to be hand-built.
9. **Threaded generation.** Upstream generates on a `threading.Thread` and
   returns to the main loop via `GLib.idle_add`. The port needs the equivalent
   (`GLib::Idle.add` from a Ruby thread) or the loading screen is pointless.
