# Porting — Paper-Clip-rb

Resume point for the next run. Factual status only; the reasoning and the
cost-to-the-user write-ups live in `.reports/`.

## Upstream

Paper Clip, implemented in Ruby (GTK4 + Libadwaita port of a Vala app). The
original opens a single PDF and lets you view and edit its metadata — title,
author, creation software, subject, conversion software, creation/
modification dates and keywords — writing the changes back to the original
file or to a new one, with the non-editable PDF properties listed read-only
beside a page-one thumbnail.

Upstream is Vala: GTK4 + libadwaita 1.x, GtkBuilder `.ui` templates, Poppler
for PDF, Exempi for XMP. The spec lives on the `origin/main` ref in this same
repo, at `c4db98e0bc2b8921d78c9e3fbf3d85ad2a124bd0`. Read it with
`git show origin/main:<path>` and `git ls-tree -r --name-only origin/main`.
It is never checked out and never merged.

## Done

Observed working this run via a fresh execution of both the drive harness
and the spec suite (see **Runtime**). One upstream source file maps to one
`lib/paper_clip/<thing>.rb`; a GtkBuilder template and the class that drives
it become one declarative Ruby class, so upstream's `.ui` files have no port
file of their own.

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
| `lib/paper_clip/models.rb` | the gem's own entry module (no single upstream counterpart) |

29 files under `lib/paper_clip/`, all 29 reached by the drive harness this
run.

### Data

| Port | Upstream |
|---|---|
| `data/io.github.diegoivan.pdf_metadata_editor.desktop.in` | same path |
| `data/io.github.diegoivan.pdf_metadata_editor.metainfo.xml.in` | same path |
| `data/io.github.diegoivan.pdf_metadata_editor.gschema.xml` | same path (empty of keys both sides) |
| `data/io.github.diegoivan.pdf_metadata_editor.service.in` | same path |
| `data/icons/hicolor/**` (plus `index.theme`) | `data/icons/hicolor/**` |
| `data/icons/hicolor/scalable/actions/*.svg` | the five symbolic icons in `src/pdf-metadata-editor.gresource.xml` |
| `data/nautilus-extension/paper-clip.py` | same path, carried as upstream's Python with the `Exec` path repointed |
| `po/**` | `po/**` |

No gresource manifest is written — a Ruby port has no GResource compiler to
target. The payload it bundled is carried as a filesystem icon theme
(`Application#register_icons`) and the heredoc in `lib/paper_clip/style.rb`.

### Entry points

- `exe/paper-clip` → `require "paper_clip"` → `PaperClip::Main.run`. GUI
  path; loads `gtk4`.
- `lib/paper/clip/rb.rb` → `lib/paper_clip/models.rb`. Gem library path,
  which the spec suite loads; stops short of the widget toolkit so it runs
  with no display.

## Runtime

Drive harness, run fresh this session:

```
nix develop --command xvfb-run -a ruby test/drive_paper_clip.rb
```

Result: **318 of 318 checks passed — `DRIVE OK`**, exit 0. 29 files under
`lib/paper_clip/` covered; 19 screenshots taken and read back.

Spec suite, run fresh this session:

```
nix develop --command xvfb-run -a ruby -e 'require "rspec/core"; exit RSpec::Core::Runner.run(["--format", "progress", "--require", "spec_helper", "spec"])'
```

Result: **134 examples, 0 failures**.

Both commands were executed in this session, not inferred from prior
commits or `.reports/` prose.

## Not started

| Upstream | Note |
|---|---|
| `src/pdf-metadata-editor.gresource.xml` | a Ruby port has no gresource compiler; the icons and stylesheet it bundled are carried by other means (see **Done → Data**) |
| upstream's three `meson test` validators as a literal 1:1 port | ported instead as `rake test:data`, which runs the same three tools (`desktop-file-validate`, `appstreamcli validate --no-net --explain`, `glib-compile-schemas --strict --dry-run`) against the merged data files |

Everything else upstream has a Ruby counterpart.

## Open gaps

The round 8 audit (`.reports/component-parity.md`, `.reports/test-parity.md`,
`.reports/accountability-ensurance.md`, `.reports/translation-parity.md`,
`.reports/component-identification.md`) reports **0 open gaps**: 0 confirmed
missing widgets/CSS/signals/actions, 0 driven-but-unverified branches, 0 new
scanner or excuse-construction hits, 0 translation discrepancies. All 18
gaps logged across eight audit rounds are closed; `.reports/component-
parity.md` carries the row-by-row verification of the last 5 (`Thumbnailer`
`ExportError`/`CacheError`, `DocumentView`'s `@loading` guard, `DateRow`'s
`@syncing` guard, `Window#proceed_with_state`'s Discard and empty-selection
call sites), each re-read against the actual new drive-harness assertions
rather than trusted from a commit message.

This session reproduced the headline numbers those reports cite (318/318
drive, 134/0 spec) live rather than re-citing them, and found no
discrepancy.

## Blockers

1. **Exempi (XMP) has no Ruby binding and no introspection data** — upstream
   ships its own `vapi/exempi-2.0.vapi`. `Document.save_xmp` and `has_xmp`
   cannot be ported as written; it needs an FFI binding to libexempi or an
   exiftool shell-out. Worked around by `lib/paper_clip/xmp_packet.rb`,
   which rewrites the packet in Ruby for files that carry one. `Xmp.init`/
   `terminate` have nothing to call.
2. **`Adw.MessageDialog`**, which `SaveChangesDialog` subclasses upstream,
   is deprecated in libadwaita 1.6, and the Ruby binding for the
   `<responses>` block with per-response appearance is unverified. Rebuilt
   on `Adwaita::AlertDialog` with responses added in code.
3. **`GLib.BindingGroup` and `bind_property` with `BIDIRECTIONAL|SYNC_CREATE`**
   are the spine of `DocumentView`, `KeywordRow` and `DocumentRow` upstream.
   GObject property binding is not usefully exposed in the Ruby bindings, so
   all of it became explicit `notify::` handlers behind a `@loading`/
   `@syncing` re-entrancy guard — now driven (see **Open gaps**).
4. **`data/nautilus-extension/paper-clip.py` cannot be ported.** A Nautilus
   extension must be a Python or C GObject plugin loaded into the Nautilus
   process; Ruby is not a supported extension language. The file stays as
   upstream's Python with its `Exec` path repointed.
5. **`Adwaita::Application` and `Adwaita::ApplicationWindow` are broken in
   the Ruby bindings**, so the port cannot subclass the application as
   upstream does (`Adw.Application` with activate/startup/shutdown/open/
   handle_local_options overrides). It uses `Gtk::Application` plus
   `Adwaita.init`, connects signals, and parses ARGV itself. The window
   class is still `Adwaita::ApplicationWindow`, which does work.
6. **`GtkShortcutsWindow`** (`src/gtk/shortcut-window.ui`) is deprecated in
   GTK 4.18, so the shortcuts window was rebuilt as an
   `Adwaita::ShortcutsDialog` rather than ported literally. The section's
   `max-height = 10` has no Adwaita counterpart.
7. **The GSettings schema `data/io.github.diegoivan.pdf_metadata_editor.gschema.xml`
   is empty** (no keys) on both sides, so there is no preferences component
   and no `settings.rb` to port. Anything resembling one would be
   invention, not parity.

Settled, not blockers: Poppler (via `Poppler-0.18.typelib`, built with
introspection support) and `Gtk::Snapshot` scaling (all calls upstream uses
exist and are driven) — see `.reports/` for history.
