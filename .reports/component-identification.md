# Component identification — audit of the existing census

| | |
|---|---|
| Upstream | `main` @ `2be119d` |
| Port | `ruby` @ `5ee083b` |

This round re-opened `.reports/component-inventory.md` (written on a prior
pass) rather than re-walking the whole tree from zero, because that document
already does the Step 1–5 work correctly: it finds the `.blp` templates
first, unions each upstream `.py`+`.blp` pair into one port file, lists
widgets with their CSS classes, signals and notes, and calls out repeaters
and conditionals instead of hiding them. Spot checks against
`git show origin/main:<path>` for `src/screens/finished_page.py`,
`src/screens/help_dialog.py` and `data/blueprints/window.blp` confirm its
widget/CSS/signal rows are accurate, and every `lib/sudoku/*.rb` file it
names exists on `ruby` at the line count it claims.

Two corrections this pass made to the existing document's own bookkeeping,
not to its component rows:

1. **Blocker #4 is stale.** The inventory still says "`po/LINGUAS` omits
   `de`". `po/LINGUAS` on `ruby` now lists `de`, `fa`, `nl`, `vi`, `zh` — five
   entries, alphabetical, `de` included. This was fixed after the inventory
   was last written and the inventory was not updated to say so.
2. **The "13 components, 13 present" status summary is a file-existence
   count, not a parity count.** Every `lib/sudoku/<thing>.rb` named in the
   inventory exists, but "present" here only means Step 1–3 (the file is
   there, the widgets are named). It does not mean Step 4–5 of
   `component-identification` (reading for repeaters/conditionals/dynamic CSS)
   was done *on the port side* to the same depth as the upstream side, and it
   says nothing about whether the port's widgets carry the same behaviour —
   that comparison is `component-parity`'s job and is reported separately in
   `.reports/component-parity.md`. Treat "present" in the existing inventory
   as "a port file exists for this upstream unit", not as "ported correctly".

No new upstream file was found missing a port-side counterpart beyond what
the existing inventory already lists as present. The unit list (13 UI
sections + 11 non-UI files) is accepted as this round's census; what changed
this round is the parity comparison run against it, in the four companion
reports.
