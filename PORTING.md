# Porting — Paper-Clip-rb

Resume point for the next run. Factual status only; the reasoning and the
cost-to-the-user write-ups live in `.reports/`, `COMPONENT_PARITY.md`,
`TEST_PARITY.md` and `FINDINGS.md`.

## Upstream

Paper Clip is a GNOME utility that opens a single PDF and lets you view and
edit its metadata — title, author, creation software, subject, conversion
software, creation/modification dates and keywords — writing the changes back
to the original file or to a new one, with the non-editable PDF properties
listed read-only beside a page-one thumbnail.

Implemented in Vala: GTK4 + libadwaita 1.x, GtkBuilder `.ui` templates,
Poppler for PDF, Exempi for XMP.

The spec lives on the `origin/main` ref in this same repo, at
`c4db98e0bc2b8921d78c9e3fbf3d85ad2a124bd0` (2025-04-28). Read it with
`git show origin/main:<path>` and `git ls-tree -r --name-only origin/main`.
It is never checked out and never merged.

## Done

Implemented and believed complete. "Believed" is load-bearing: no unit in
this column has been observed running — see **Open gaps**, gap 5.

One upstream source file maps to one `lib/paper_clip/<thing>.rb`. A
GtkBuilder template and the class that drives it become one declarative Ruby
class, so upstream's `.ui` files have no port file of their own.

### Widgets

| Port | Upstream |
|---|---|
| `lib/paper_clip/window.rb` | `src/window.vala` + `src/window.ui` |
| `lib/paper_clip/window_state.rb` | the `WindowState` enum at the foot of `src/window.vala` |
| `lib/paper_clip/primary_menu.rb` | `src/window.ui` `<menu id="primary_menu">` |
| `lib/paper_clip/document_view.rb` | `src/DocumentView.vala` + `src/gtk/document-view.ui` |
| `lib/paper_clip/date_row.rb` | `src/DateRow.vala` + `src/gtk/date-row.ui` |
| `lib/paper_clip/details_list.rb` | `src/DetailsList.vala` + `src/gtk/details-list.ui` |
| `lib/paper_clip/string_array_row.rb` | `src/StringArrayRow.vala` (both classes) |
| `lib/paper_clip/keyword_list.rb` | `src/KeywordList.vala` + `src/gtk/keyword-list.ui` |
| `lib/paper_clip/keyword_row.rb` | `src/KeywordRow.vala` |
| `lib/paper_clip/drop_overlay.rb` | `src/DropOverlay.vala` |
| `lib/paper_clip/save_changes_dialog.rb` | `src/SaveChangesDialog.vala` + `src/gtk/save-changes-dialog.ui` |
| `lib/paper_clip/document_row.rb` | `PaperClip.DocumentRow`, foot of `src/SaveChangesDialog.vala` |
| `lib/paper_clip/password_dialog.rb` | `src/PasswordDialog.vala` + `src/gtk/password-dialog.ui` |
| `lib/paper_clip/shortcuts_dialog.rb` | `src/gtk/shortcut-window.ui` |

### Application and services

| Port | Upstream |
|---|---|
| `lib/paper_clip/application.rb` | `src/application.vala` (actions, lifecycle, startup) |
| `lib/paper_clip/about_dialog.rb` | `src/application.vala` `on_about_action` + `generate_debug_info` |
| `lib/paper_clip/translations.rb` | the three `Intl` calls in `src/application.vala` |
| `lib/paper_clip/main.rb` | `src/main.vala` + the `OptionEntry[]` table |
| `lib/paper_clip/document.rb` | `src/Document.vala` (model, parse, save) |
| `lib/paper_clip/pdf_strings.rb` | the string tables inside `src/Document.vala` |
| `lib/paper_clip/xmp_packet.rb` | `src/Document.vala:227-270` (the Exempi block) |
| `lib/paper_clip/pdf_crypt.rb` | Poppler's own security handler, which upstream never writes itself |
| `lib/paper_clip/document_manager.rb` | `src/Services/DocumentManager.vala` |
| `lib/paper_clip/thread_manager.rb` | `src/ThreadManager.vala` |
| `lib/paper_clip/style.rb` | `src/style.css` |
| folded into `password_dialog.rb` (`on_password:` / `on_cancel:`) | `src/Models/AsyncTask.vala` |

### Data

| Port | Upstream |
|---|---|
| `data/io.github.diegoivan.pdf_metadata_editor.desktop.in` | same path |
| `data/io.github.diegoivan.pdf_metadata_editor.metainfo.xml.in` | same path |
| `data/io.github.diegoivan.pdf_metadata_editor.gschema.xml` | same path (empty of keys both sides) |
| `data/icons/hicolor/**` (plus `index.theme`) | `data/icons/hicolor/**` |
| `data/icons/hicolor/scalable/actions/*.svg` | the five symbolic icons in `src/pdf-metadata-editor.gresource.xml` |
| `data/nautilus-extension/paper-clip.py` | same path, carried as upstream's Python with the `Exec` path repointed |
| `po/**` | `po/**`, carried over unchanged except `POTFILES` |
| no counterpart by design | `src/pdf-metadata-editor.gresource.xml` — a Ruby port has no gresource; the icons are a filesystem icon theme registered by `Application#register_icons` |

### Entry points

- `exe/paper-clip` → `require "paper_clip"` → `PaperClip::Main.run`. GUI path;
  loads `gtk4`.
- `lib/paper/clip/rb.rb` → `lib/paper_clip/models.rb`. Gem library path, which
  the spec suite loads; stops short of the widget toolkit so it runs with no
  display.

### Port-side tests

130 examples, 0 failures, by `nix develop --command rspec --no-color -f progress`
at the last audit. They cover the date parser, the keyword round-trip, the
`/Encrypt /P` bit map, the incremental-update writer, the security handler
across four revisions, the XMP mirror and the dirty flag. No widget test of
any kind: nothing in `spec/` constructs an `Adwaita::` object.

## Not started

Upstream components with no Ruby counterpart:

| Upstream | Note |
|---|---|
| `src/DocumentThumbnail.vala` | the editor page's first child; see Blockers 1 and 3 |
| `src/Services/Thumbnailer.vala` | off-loop render, `$TMPDIR/thumbnails` cache, `ThumbnailError`; see Blocker 1 |
| `data/io.github.diegoivan.pdf_metadata_editor.service.in` | D-Bus activation; not blocked by anything, just not written |

Upstream's three meson validation tests (`desktop-file-validate`,
`appstreamcli validate`, `glib-compile-schemas --strict --dry-run`) have no
port equivalent in the Rakefile or `spec/`.

## Open gaps

13 gaps across the four parity reports in `.reports/`, and clean=false.

From `.reports/component-parity.md` (5):

1. The page-one preview does not exist. `document_view.rb:95` makes the
   filename label the box's first child where upstream places
   `PaperClipDocumentThumbnail`. The largest gap in the port.
2. `Services/Thumbnailer` has no counterpart at all, so upstream's
   degrade-on-huge-page path and its `FAILED_EXPORT` / `FAILED_TO_CACHE`
   reporting have nowhere to live.
3. No D-Bus service file, so nothing can start the app by its bus name.
4. The About dialog's debug block cannot name the PDF or XMP library;
   `about_dialog.rb:66-67` prints two sentences saying neither is linked where
   upstream prints Poppler and Exempi versions.
5. Nothing on the port side has been confirmed to render or fire. There is no
   display and no X server in the closure or on the host; `require "adwaita"`
   raises `Gtk::InitError`. Every parity verdict in the reports is a reading
   of source. In particular `window.rb:151` builds an
   `Adwaita::ApplicationWindow`, which the `ruby-gtk` skill records as broken
   in these bindings — if the skill is right the window does not open and the
   other verdicts are moot. Remedy is a one-line `flake.nix` change
   (`pkgs.xvfb-run`), then drive and screenshot each unit.

From `.reports/component-identification.md` (3): `DocumentThumbnail` and
`Thumbnailer` have no port unit; `*.service.in` has no port unit. (These
overlap gaps 1–3 above as identification-level findings and are counted
separately by that report.)

From `.reports/test-parity.md` (3): all three upstream meson validation tests
are unported.

From `.reports/translation-parity.md` (2): `po/pdf-metadata-editor.pot` was
overwritten and the replacement drops 5 of the 96 keys; a gem-installed Paper
Clip is untranslated in all 18 languages because the `.mo` files are compiled
and installed only by the flake.

`.reports/accountability-ensurance.md` reports 0 scanner hits in `lib/`,
`exe/` and `spec/`, and 4 findings in what the code *says* about its gaps.

## Blockers

1. **Poppler has no Ruby binding in the gtk4-era ruby-gnome family.** Every
   metadata read/write, `n_pages`, the permission and viewer-preference flags,
   the layout/duplex/subtype enums and the page render go through
   libpoppler-glib. The old `poppler` gem is GTK2/Cairo-era. Options: load the
   Poppler-0.18 typelib through gobject-introspection, or shell out to
   `exiftool`/`qpdf`. Gates `document.rb`, `details_list.rb`,
   `document_thumbnail.rb` and `thumbnailer.rb`. Worked around for the
   metadata half by the port's own pure-Ruby PDF parser/writer
   (`document.rb`, `pdf_strings.rb`, `pdf_crypt.rb`); not worked around for
   rendering, which is why the thumbnail is absent.
2. **Exempi (XMP) has no Ruby binding and no introspection data** — upstream
   ships its own `vapi/exempi-2.0.vapi`. `Document.save_xmp` and `has_xmp`
   (producer, creator tool, keywords, `dc:title`, CreateDate, ModifyDate,
   MetadataDate) cannot be ported as written; it needs an FFI binding to
   libexempi or an exiftool shell-out. Worked around by
   `lib/paper_clip/xmp_packet.rb`, which rewrites the packet in Ruby for files
   that carry one. `Xmp.init`/`terminate` have nothing to call.
3. **`DocumentThumbnail`'s `Gtk.Snapshot` scaling** (`append_color`,
   `append_scaled_texture` with a `Graphene.Rect`, `to_paintable`,
   `Gsk.ScalingFilter`) is a thin GSK wrapper whose availability in the Ruby
   bindings is unverified. Fallback is GdkPixbuf scaling plus a Cairo white
   background, which loses the filter choice.
4. **`Adw.MessageDialog`**, which `SaveChangesDialog` subclasses, is
   deprecated in libadwaita 1.6, and the Ruby binding for the `<responses>`
   block with per-response appearance is unverified. Rebuilt on
   `Adwaita::AlertDialog` with responses added in code.
5. **`GLib.BindingGroup` and `bind_property` with `BIDIRECTIONAL|SYNC_CREATE`**
   are the spine of `DocumentView`, `KeywordRow` and `DocumentRow`. GObject
   property binding is not usefully exposed in the Ruby bindings, so all of it
   became explicit `notify::` handlers behind a `@loading` re-entrancy guard.
   Portable, but the largest rewrite in the port and the easiest place to
   introduce an edit loop. Unobserved, per gap 5.
6. **`data/nautilus-extension/paper-clip.py` cannot be ported.** A Nautilus
   extension must be a Python or C GObject plugin loaded into the Nautilus
   process; Ruby is not a supported extension language. The file stays as
   upstream's Python with its `Exec` path repointed.
7. **`Adwaita::Application` and `Adwaita::ApplicationWindow` are broken in the
   Ruby bindings**, so the port cannot subclass the application as upstream
   does (`Adw.Application` with activate/startup/shutdown/open/
   handle_local_options overrides). It uses `Gtk::Application` plus
   `Adwaita.init`, connects signals, and parses ARGV itself. Note the
   inconsistency recorded in gap 5: the window class is still
   `Adwaita::ApplicationWindow`.
8. **`GtkShortcutsWindow`** (`src/gtk/shortcut-window.ui`) is deprecated in
   GTK 4.18, so the shortcuts window was rebuilt as an
   `Adwaita::ShortcutsDialog` following the pilot's `lib/shortcuts_dialog.rb`
   rather than ported literally. The section's `max-height = 10` has no
   Adwaita counterpart.
9. **The GSettings schema `data/io.github.diegoivan.pdf_metadata_editor.gschema.xml`
   is empty** (no keys), so there is no preferences component and no
   `settings.rb` to port. Anything resembling one would be invention, not
   parity.

## Next run

In order:

1. Settle gap 5. Add `pkgs.xvfb-run` to the devShell, then instantiate
   `Application` and `Window` and find out whether
   `Adwaita::ApplicationWindow` works at all. Everything else in this port is
   a reading, not a result, until this runs.
2. `DocumentThumbnail` + `Thumbnailer` (Blockers 1 and 3).
3. The three widget-level guards `TEST_PARITY.md` lists as owed, which need
   (1) first.
4. `data/*.service.in`.
5. Restore the 5 dropped `.pot` keys; install the `.mo` files from the gem as
   well as from the flake.
