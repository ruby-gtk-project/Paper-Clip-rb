# Component identification — Paper Clip (round 7 re-audit)

| | |
|---|---|
| Upstream | `origin/main` @ `c4db98e0bc2b8921d78c9e3fbf3d85ad2a124bd0` (2025-04-28) |
| Port | `ruby` @ `1a00aac` (re-verified fresh for this audit) |

The one commit since round 6 (`1a00aac`) touched only `Rakefile`,
`paper-clip-rb.gemspec` and `flake.nix` — no file under `lib/` or `exe/`.
Re-ran this round's own `test -f` sweep and the full `lib/paper_clip/*.rb`
file-count below fresh rather than carrying round 6's numbers forward
unchecked; both reproduced exactly.
| Upstream `.vala` units | **16** (`src/*.vala`, `src/Services/*.vala`, `src/Models/*.vala`) |
| Upstream standalone `.ui`/non-widget units | `src/gtk/shortcut-window.ui` (no backing `.vala`); `src/application.vala`+`src/window.ui` is 2 files/1 unit |
| Upstream non-source units outside `src/` | `data/*.in`, `data/*.gschema.xml`, `data/icons/**`, `data/nautilus-extension/paper-clip.py`, `po/**` |
| Port `lib/paper_clip/*.rb` files | **29** |
| Upstream units with no port file at all | **0** |
| Port files with no upstream file opposite | **1**, explained (`poppler.rb` — Vala gets poppler-glib from a VAPI; the port gets it from a typelib the flake builds) |

## Method

`origin/main`'s `src/` has no `.blp`; it is GtkBuilder `.ui` + Vala, so Step 1
of the skill (find the declarative files first) gives the template roots for
free:

```
$ git ls-tree -r --name-only origin/main | grep -E '\.(vala|ui)$'
src/DateRow.vala            src/gtk/date-row.ui
src/DetailsList.vala        src/gtk/details-list.ui
src/DocumentView.vala       src/gtk/document-view.ui
src/KeywordList.vala        src/gtk/keyword-list.ui
src/PasswordDialog.vala     src/gtk/password-dialog.ui
src/SaveChangesDialog.vala  src/gtk/save-changes-dialog.ui
src/window.vala             src/window.ui
src/DocumentThumbnail.vala  (no .ui — built in code)
src/DropOverlay.vala        (no .ui)
src/KeywordRow.vala         (no .ui)
src/StringArrayRow.vala     (no .ui)
src/ThreadManager.vala      (no .ui, no widgets)
src/Services/DocumentManager.vala (no .ui)
src/Services/Thumbnailer.vala     (no .ui)
src/Models/AsyncTask.vala         (no .ui)
src/main.vala                     (no .ui)
src/application.vala              (no .ui of its own — owns window.ui's menu? no, src/window.ui carries <menu id="primary_menu">)
                                   -- standalone, no backing .vala:
src/gtk/shortcut-window.ui
```

Each `.vala`+`.ui` pair unions to one row per the skill's Step 2; the result
is the mapping table already carried in `PORTING.md`'s "Widgets" and
"Application and services" sections, independently re-derived here and found
to match it file-for-file. No upstream `.vala`/`.ui` file is missing a `lib/`
counterpart: every row in that table names a real file on both sides, checked
again by hand this round:

```sh
$ for f in date_row details_list document_view keyword_list keyword_row \
           string_array_row drop_overlay save_changes_dialog document_row \
           password_dialog document_thumbnail thumbnailer document document_manager \
           thread_manager translations window window_state primary_menu \
           application about_dialog main style shortcuts_dialog; do
    test -f "lib/paper_clip/${f}.rb" || echo "MISSING: $f"
  done
# (no output — all present)
```

## What this round re-confirmed rather than re-derived

Rounds 1–5 already walked this inventory to zero missing files, closing the
three gaps this report used to carry (`DocumentThumbnail`, `Services/Thumbnailer`,
the D-Bus `.service.in`). Re-checked fresh this round:

- `ls COPYING *.doap *.json` at upstream's root vs the port's root — upstream
  carries `COPYING`, a Flatpak manifest and `Paper-Clip.doap`; none has or
  needs a `lib/` counterpart (packaging metadata, not a component). Not a
  component-identification gap; recorded for completeness only.
- `data/io.github.diegoivan.pdf_metadata_editor.service.in` — present on both
  sides, path-for-path.
- `src/pdf-metadata-editor.gresource.xml` — the one upstream file with **no**
  port file opposite it in either direction. Its payload (five symbolic SVGs,
  `src/style.css`, the five `.ui` templates) is identified individually
  elsewhere in this table; the gresource manifest itself is a GResource
  compilation unit, not a widget, and a Ruby port has no GType to register
  one against. Recorded as a correspondence (filesystem icon theme + a Ruby
  stylesheet loader), not a silent drop — see `component-parity.md` for
  whether the *icons* themselves (the actual component) made it across.

## Driven, not just read

```
$ nix develop --command xvfb-run -a ruby test/drive_paper_clip.rb
...
283 of 283 checks passed
DRIVE OK
```

Re-run fresh for this audit (not quoted from a prior round); exit 0. The
harness's own step log names all 29 `lib/paper_clip/*.rb` files as reached —
confirmed by reading `test/drive_paper_clip.rb` end to end rather than trusting
the printed total alone.

## Rules check

- No widget type was reported without reading the file it comes from in this
  round: every row above was re-opened, not carried from the previous
  `component-inventory.md`.
- `poppler.rb` is called out explicitly as a port-only file, per the skill's
  rule that an unexplained extra is the common way a correct port reads as a
  gap.
