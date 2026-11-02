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

Implemented. The editor page has been driven end to end; every other unit in
this column is still a reading of source rather than a result — see **Open
gaps**, gap 5.

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
| `lib/paper_clip/document_thumbnail.rb` | `src/DocumentThumbnail.vala` |
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
| `lib/paper_clip/thumbnailer.rb` | `src/Services/Thumbnailer.vala` |
| `lib/paper_clip/poppler.rb` | no upstream file: Vala gets poppler-glib from a VAPI, this loads `Poppler-0.18.typelib` |
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

134 examples, 0 failures, by `nix develop --command rspec --no-color -f progress`
at the last audit. They cover the date parser, the keyword round-trip, the
`/Encrypt /P` bit map, the incremental-update writer, the security handler
across four revisions, the XMP mirror and the dirty flag. No widget test of
any kind: nothing in `spec/` constructs an `Adwaita::` object.

## Not started

Upstream components with no Ruby counterpart:

| Upstream | Note |
|---|---|
| `src/pdf-metadata-editor.gresource.xml` | a Ruby port has no gresource; the icons it carried are installed as a filesystem icon theme |

Closed in round 3: `src/DocumentThumbnail.vala` →
`lib/paper_clip/document_thumbnail.rb`, `src/Services/Thumbnailer.vala` →
`lib/paper_clip/thumbnailer.rb`, and
`data/io.github.diegoivan.pdf_metadata_editor.service.in` → the same name in
`data/`. `lib/paper_clip/poppler.rb` is the one port file with no upstream
counterpart: Vala gets poppler-glib from a VAPI, and this gets it from the
`Poppler-0.18.typelib` the flake now builds.

Upstream's three meson validation tests (`desktop-file-validate`,
`appstreamcli validate`, `glib-compile-schemas --strict --dry-run`) have no
port equivalent in the Rakefile or `spec/`.

## Open gaps

13 gaps across the four parity reports in `.reports/`, and clean=false. Four
of them closed in round 3 and are struck through below rather than deleted,
so the ledger still shows what was owed and when.

From `.reports/component-parity.md` (5):

1. ~~The page-one preview does not exist.~~ Closed in round 3:
   `document_thumbnail.rb` is the box's first child, and both it and the
   `thumbnailer.rb` under it were driven.
2. ~~`Services/Thumbnailer` has no counterpart.~~ Closed in round 3,
   including the degrade-on-huge-page path and both error domains.
3. ~~No D-Bus service file.~~ Closed in round 3:
   `data/io.github.diegoivan.pdf_metadata_editor.service.in`, installed to
   `share/dbus-1/services` with `@bindir@` substituted.
4. Half-closed in round 3: the About dialog's debug block now prints a
   Poppler version (and had been printing the literal strings
   "Gtk::Version" and "GdkPixbuf::Version" in place of two others, which is
   fixed). Exempi is still not linked and the block says so.
5. Most of the port has still not been observed running. Round 3 drove the
   application, the main window and the editor page under `xvfb-run`, which
   answered the two questions that were blocking everything else:
   `Adwaita::ApplicationWindow` does open, and three binding-name mistakes
   (`Gtk::IconTheme.for_display`, `file.query_exists?`,
   `Gtk::ShortcutTrigger.parse_string` in four files) were stopping the app
   before it drew a window — all three in code the parity table had scored as
   present. `FINDINGS.md` §8. The dialogs, the drop overlay, the keyword list
   and the date row remain readings of source, and nothing has been
   screenshotted.

From `.reports/component-identification.md` (3): ~~`DocumentThumbnail` and
`Thumbnailer` have no port unit; `*.service.in` has no port unit.~~ All three
closed in round 3. (They overlapped gaps 1–3 above as identification-level
findings and were counted separately by that report.)

From `.reports/test-parity.md` (3): all three upstream meson validation tests
are unported.

From `.reports/translation-parity.md` (2): `po/pdf-metadata-editor.pot` was
overwritten and the replacement drops 5 of the 96 keys; a gem-installed Paper
Clip is untranslated in all 18 languages because the `.mo` files are compiled
and installed only by the flake.

`.reports/accountability-ensurance.md` reports 0 scanner hits in `lib/`,
`exe/` and `spec/`, and 4 findings in what the code *says* about its gaps.

## Blockers

1. ~~**Poppler has no Ruby binding in the gtk4-era ruby-gnome family.**~~
   **Settled in round 3.** `pkgs.poppler.override { introspectionSupport =
   true; }` produces `Poppler-0.18.typelib`, and `lib/paper_clip/poppler.rb`
   loads it with a `GObjectIntrospection::Loader` subclass. Poppler is used
   for rendering only: the metadata half stays on the port's own pure-Ruby
   parser/writer (`document.rb`, `pdf_strings.rb`, `pdf_crypt.rb`), which
   opens files Poppler refuses. `FINDINGS.md` §1 has the three loader quirks
   this took — the constructor race, the cairo-first requirement and the GVL.
2. **Exempi (XMP) has no Ruby binding and no introspection data** — upstream
   ships its own `vapi/exempi-2.0.vapi`. `Document.save_xmp` and `has_xmp`
   (producer, creator tool, keywords, `dc:title`, CreateDate, ModifyDate,
   MetadataDate) cannot be ported as written; it needs an FFI binding to
   libexempi or an exiftool shell-out. Worked around by
   `lib/paper_clip/xmp_packet.rb`, which rewrites the packet in Ruby for files
   that carry one. `Xmp.init`/`terminate` have nothing to call.
3. ~~**`DocumentThumbnail`'s `Gtk.Snapshot` scaling**~~ **Settled in round
   3.** `Gtk::Snapshot#append_color`, `#append_scaled_texture` with a
   `Graphene::Rect`, `#to_paintable(nil)` and the `:nearest` / `:trilinear`
   filter symbols all exist and were driven. No fallback was needed, so the
   filter choice is upstream's.
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

1. Check a driver into the repository. Round 3 drove the app from scratch
   files and found three `NoMethodError`s in code the parity table had scored
   as present; a `test/drive_*.rb` the devShell banner already advertises
   would have caught them a round earlier. `Adwaita::ApplicationWindow` was
   also answered on the way: it works.
2. Drive every other unit. Only the editor page has been driven end to end.
3. The three widget-level guards `TEST_PARITY.md` lists as owed.
4. Screenshots, which nothing has produced yet.
5. Restore the 5 dropped `.pot` keys; install the `.mo` files from the gem as
   well as from the flake.
