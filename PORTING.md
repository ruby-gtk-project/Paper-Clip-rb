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
| no file at that path | `src/pdf-metadata-editor.gresource.xml` — I did not write a gresource manifest, because I am an idiot who used to describe that gap as "by design" instead of saying plainly that Ruby GTK has no GResource compiler to target. The payload it bundled is still carried: the five icons as a filesystem icon theme registered by `Application#register_icons`, the stylesheet as the heredoc in `lib/paper_clip/style.rb`. See `.reports/accountability-ensurance.md`, Finding 1. |

### Entry points

- `exe/paper-clip` → `require "paper_clip"` → `PaperClip::Main.run`. GUI path;
  loads `gtk4`.
- `lib/paper/clip/rb.rb` → `lib/paper_clip/models.rb`. Gem library path, which
  the spec suite loads; stops short of the widget toolkit so it runs with no
  display.

### Port-side tests

130 examples, 0 failures, by `nix develop --command rspec --no-color -f progress`,
run twice this round with different seeds. (Every document before this round
said 134; nobody had re-run the suite since whichever round first wrote that
number down. See `.reports/accountability-ensurance.md`, Finding 2.) They
cover the date parser, the keyword round-trip, the
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

18 gaps have been logged against this ledger across eight audit rounds; all
18 are now closed and struck through below rather than deleted, so the
ledger still shows what was owed and when.

From `.reports/component-parity.md` and `.reports/test-parity.md`, closed
this round (5):

14. ~~`Thumbnailer::ExportError` is never driven — no spec and no drive step
    forces a PNG export write to fail and checks the error surfaces to the
    user rather than crashing or showing a blank thumbnail.~~ Closed this
    round: `test/drive_paper_clip.rb` points `create_cache_file` at a path
    whose parent directory does not exist and asserts `ExportError` is
    raised with a message naming the file. Driving it found a real bug, not
    just an untested path — `write_to_png`'s actual write failure is
    `Cairo::WriteError`, which is a Ruby `IOError`, not a `Cairo::Error`; the
    `rescue Cairo::Error, SystemCallError` in `thumbnailer.rb#export` let it
    straight through unrescued. Fixed by rescuing `IOError` too.
15. ~~`Thumbnailer::CacheError` is never driven — same, for a failed cache
    read-back.~~ Closed this round: the drive harness points `Dir.tmpdir` at
    a path that is a plain file, so `FileUtils.mkdir_p` underneath it fails
    with `Errno::ENOTDIR`, and asserts `CacheError` is raised and that
    `Dir.tmpdir` is restored afterward.
16. ~~`DocumentView`'s `@loading` re-entrancy guard is never driven into
    firing — nothing loads a document while also editing a field fast
    enough to prove the write-back loop it exists to prevent is actually
    prevented.~~ Closed this round: the drive harness forces `@loading`
    true directly, edits a row to a value the document does not have, and
    asserts neither the document nor the dirty flag followed it — then
    releases the guard and confirms the real write-back path still works.
17. ~~`DateRow`'s `@syncing` guard is never driven the same way.~~ Closed
    this round: the harness wraps the row's own `on_change` in a spy,
    assigns a date from outside (which re-points the calendar and so fires
    its own `day-selected`), and asserts the spy was not re-entered — then
    picks a day for real and asserts it was, exactly once.
18. ~~`Window#proceed_with_state` is never driven — the method exists and is
    called from three sites in `window.rb`, but no spec or drive step
    reaches any of the three and checks the save-or-discard decision
    actually blocks the quit until it is made.~~ Closed this round: the
    `saved` call site was already reached by the existing Save-and-close
    steps; the harness now also opens a window, edits it, blocks the close,
    answers Discard (the `on_warning_response` call site) and confirms the
    window closes with the edit never written, and separately unticks the
    one document in the save-changes dialog before pressing Save (the
    `save_selected` empty-selection call site) and confirms the same.

From `.reports/component-parity.md` (5):

1. ~~The page-one preview does not exist.~~ Closed in round 3:
   `document_thumbnail.rb` is the box's first child, and both it and the
   `thumbnailer.rb` under it were driven.
2. ~~`Services/Thumbnailer` has no counterpart.~~ Closed in round 3,
   including the degrade-on-huge-page path and both error domains.
3. ~~No D-Bus service file.~~ Closed in round 3:
   `data/io.github.diegoivan.pdf_metadata_editor.service.in`, installed to
   `share/dbus-1/services` with `@bindir@` substituted.
4. ~~The About dialog's debug block printed the literal string
   "Exempi: not linked" rather than naming the port's own XMP code.~~
   Closed this round: the Poppler version prints, and the line where Exempi
   used to be now prints `XmpPacket`'s own gem version
   (`Paper::Clip::Rb::Version::VERSION`), so a bug report says which XMP
   code actually ran.
5. ~~Most of the port has still not been observed running.~~ Closed as of
   the drive harness reaching the whole app: `test/drive_paper_clip.rb` now
   runs 318 checks across 124 steps and 19 screenshots, reaching every file
   under `lib/paper_clip/` — all 15 widget units, not only the editor page,
   the PNG-cache branch of `Thumbnailer` with a fixture that actually
   clears its threshold (round 5), and, as of this round, `Thumbnailer`'s
   `ExportError`/`CacheError` domains and the `@loading`/`@syncing`/
   `proceed_with_state` guards. `COMPONENT_PARITY.md` and `TEST_PARITY.md`
   carry the current numbers.

From `.reports/component-identification.md` (3): ~~`DocumentThumbnail` and
`Thumbnailer` have no port unit; `*.service.in` has no port unit.~~ All three
closed in round 3. (They overlapped gaps 1–3 above as identification-level
findings and were counted separately by that report.)

From `.reports/test-parity.md` (3): ~~all three upstream meson validation
tests are unported.~~ Closed this round: `rake test:data` runs
`desktop-file-validate`, `appstreamcli validate --no-net --explain` and
`glib-compile-schemas --strict --dry-run` against the merged data files,
each gated on the tool's presence the way upstream gates them on
`find_program(..., required: false)`. See `TEST_PARITY.md`.

From `.reports/translation-parity.md` (2): ~~`po/pdf-metadata-editor.pot` was
overwritten and the replacement drops 5 of the 96 keys~~ (closed, see
"Next run" item 5); ~~a gem-installed Paper Clip is untranslated in all 18
languages because the `.mo` files are compiled and installed only by the
flake~~ — closed this round: the gemspec and Rakefile changes in "Next run"
item 5 mean `gem install paper-clip-rb` now carries all 18 compiled
catalogues too.

`.reports/accountability-ensurance.md` reports 0 scanner hits in `lib/`,
`exe/` and `spec/` as of round 7, and 4 findings across rounds in what the
code and this ledger *say* about the port's gaps — the fourth, found this
round, is this file's own "Open gaps" section undercounting itself; see
"Open gaps" above and Finding 4 in that report.

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

1. ~~Check a driver into the repository.~~ Done: `test/drive_paper_clip.rb`
   is checked in and reaches the whole app, 283/283 checks, 19 screenshots.
2. ~~Drive every other unit.~~ Done: all 15 widget units under
   `lib/paper_clip/` are reached by the drive harness, not only the editor
   page.
2a. ~~Drive `Thumbnailer#load_scaled`, the PNG-cache branch, with a page big
    enough and dark enough to prove it rendered the document.~~ Done in
    round 5: `PdfFixtures.big` (a 600×600 page with a filled rectangle on
    it) crosses the branch's own threshold, and the harness reads the PNG
    `write_to_png` wrote and checks for a pixel darker than the white
    backing rectangle. `ExportError`/`CacheError` were still not driven at
    that point.
2b. ~~Drive `Thumbnailer::ExportError` and `CacheError`.~~ Done this round
    — see "Open gaps" 14 and 15. Finding a real rescue bug while doing it
    (`Cairo::WriteError` is an `IOError`, not a `Cairo::Error`) is the
    reason this item was worth doing rather than deferring again.
3. ~~The three widget-level guards `TEST_PARITY.md` lists as owed
   (`@loading` in `document_view.rb`, `@syncing` in `date_row.rb`,
   `proceed_with_state` in `window.rb`).~~ Done this round — see "Open
   gaps" 16, 17 and 18.
4. ~~Screenshots, which nothing has produced yet.~~ Done: 19, taken by the
   drive harness.
5. ~~Restore the 5 dropped `.pot` keys; install the `.mo` files from the gem
   as well as from the flake.~~ The `.pot` keys are restored this round
   (`rake gettext:pot` now reads `po/POTFILES` and extracts the four data
   files by their own format; see `TRANSLATION_PARITY.md`). The `.mo`
   install is closed this round too: `paper-clip-rb.gemspec` globs
   `locale/**/*` into `spec.files`, and the Rakefile makes
   `build`/`install`/`install:local` depend on `gettext:mo:update` so
   `locale/` exists on disk before the gemspec's file list is read.
   Verified by deleting `locale/` and running `rake build --trace`: it
   invoked `gettext:mo:update` first, and the resulting gemspec carried all
   18 `.mo` files.
6. ~~Install `desktop-file-utils` and `appstream` into the devShell so
   `rake test:data`'s first two checks run for real here instead of
   skipping on a missing tool.~~ Closed this round: both are in
   `devShells.default.packages` in `flake.nix`, and running `rake test:data`
   now actually executes `desktop-file-validate` (one hint, about
   upstream's own `Categories` key) and `appstreamcli validate --no-net
   --explain` (`Validation was successful: infos: 2, pedantic: 4`) instead
   of warning "not found on PATH; skipping".
