# Porting — Paper-Clip-rb

The enumerated unit list, the file map, and the cursor. Upstream is
`origin/main` @ `c4db98e0bc2b8921d78c9e3fbf3d85ad2a124bd0`; read it with
`git show origin/main:<path>`. It is never checked out and never merged — it
is the spec.

Parity evidence lives in `COMPONENT_PARITY.md` and `TEST_PARITY.md`. Costs and
open questions live in `FINDINGS.md`. This file is the map and the cursor and
nothing else.

## Cursor

| | |
|---|---|
| Round | 2 complete |
| Units with a port file | **19 of 21** |
| Units with no port file | 2 — `DocumentThumbnail`, `Thumbnailer` (`FINDINGS.md` §1) |
| Port specs | 130 examples, 0 failures |
| Units driven on screen | **0** (`FINDINGS.md` §8) |

Round 3's first task is `FINDINGS.md` §8: get a display into the devShell and
drive every unit. Everything else in this port is a reading, not a result.

## The file map

One upstream source file maps to one `lib/paper_clip/<thing>.rb`. Upstream's
`.ui` templates have no separate port file: a GtkBuilder template and the
class that drives it become one declarative Ruby class, so
`src/DateRow.vala` + `src/gtk/date-row.ui` → `lib/paper_clip/date_row.rb`.

### Widgets

| Upstream | Port |
|---|---|
| `src/window.vala` + `src/window.ui` | `lib/paper_clip/window.rb` |
| `src/window.ui` `<menu id="primary_menu">` | `lib/paper_clip/primary_menu.rb` |
| the `WindowState` enum at the foot of `src/window.vala` | `lib/paper_clip/window_state.rb` |
| `src/DocumentView.vala` + `src/gtk/document-view.ui` | `lib/paper_clip/document_view.rb` |
| `src/DateRow.vala` + `src/gtk/date-row.ui` | `lib/paper_clip/date_row.rb` |
| `src/DetailsList.vala` + `src/gtk/details-list.ui` | `lib/paper_clip/details_list.rb` |
| `src/StringArrayRow.vala` (both classes) | `lib/paper_clip/string_array_row.rb` |
| `src/KeywordList.vala` + `src/gtk/keyword-list.ui` | `lib/paper_clip/keyword_list.rb` |
| `src/KeywordRow.vala` | `lib/paper_clip/keyword_row.rb` |
| `src/DropOverlay.vala` | `lib/paper_clip/drop_overlay.rb` |
| `src/SaveChangesDialog.vala` + `src/gtk/save-changes-dialog.ui` | `lib/paper_clip/save_changes_dialog.rb` |
| `PaperClip.DocumentRow`, at the foot of the same file | `lib/paper_clip/document_row.rb` |
| `src/PasswordDialog.vala` + `src/gtk/password-dialog.ui` | `lib/paper_clip/password_dialog.rb` |
| `src/gtk/shortcut-window.ui` | `lib/paper_clip/shortcuts_dialog.rb` |
| `src/DocumentThumbnail.vala` | **no port file** |

### Application and services

| Upstream | Port |
|---|---|
| `src/application.vala` (actions, lifecycle, startup) | `lib/paper_clip/application.rb` |
| `src/application.vala` `on_about_action` + `generate_debug_info` | `lib/paper_clip/about_dialog.rb` |
| `src/application.vala:28-30` (the three `Intl` calls) | `lib/paper_clip/translations.rb` |
| `src/main.vala` + the `OptionEntry[]` table | `lib/paper_clip/main.rb` |
| `src/Document.vala` (model, parse, save) | `lib/paper_clip/document.rb` |
| the string tables inside `src/Document.vala` | `lib/paper_clip/pdf_strings.rb` |
| `src/Document.vala:227-270` (Exempi) | `lib/paper_clip/xmp_packet.rb` |
| Poppler's own security handler, which upstream never writes | `lib/paper_clip/pdf_crypt.rb` |
| `src/Services/DocumentManager.vala` | `lib/paper_clip/document_manager.rb` |
| `src/ThreadManager.vala` | `lib/paper_clip/thread_manager.rb` |
| `src/style.css` | `lib/paper_clip/style.rb` |
| `src/Models/AsyncTask.vala` | folded into `password_dialog.rb` — see below |
| `src/Services/Thumbnailer.vala` | **no port file** |

### Data

| Upstream | Port |
|---|---|
| `data/*.desktop.in` | `data/io.github.diegoivan.pdf_metadata_editor.desktop.in` |
| `data/*.metainfo.xml.in` | `data/io.github.diegoivan.pdf_metadata_editor.metainfo.xml.in` |
| `data/*.gschema.xml` | `data/io.github.diegoivan.pdf_metadata_editor.gschema.xml` |
| `data/icons/hicolor/**` | `data/icons/hicolor/**` (plus `index.theme`) |
| `src/gtk/*.svg` (five bundled symbolic icons, in the gresource) | `data/icons/hicolor/scalable/actions/*.svg` |
| `data/nautilus-extension/paper-clip.py` | `data/nautilus-extension/paper-clip.py` |
| `po/**` | `po/**`, carried over unchanged except `POTFILES` |
| `data/*.service.in` | **no port file** — D-Bus activation |
| `src/pdf-metadata-editor.gresource.xml` | no counterpart: a Ruby port has no gresource. The icons are a filesystem icon theme instead, registered by `Application#register_icons` |

### Entry points

- `exe/paper-clip` → `require "paper_clip"` → `PaperClip::Main.run`. This is
  the GUI path and it loads `gtk4`.
- `lib/paper/clip/rb.rb` → `lib/paper_clip/models.rb`. This is the gem's
  library path, which the spec suite loads; it stops short of the widget
  toolkit so it works with no display. See `FINDINGS.md` §9.

## Deliberate structural correspondences

Each of these is a shape change, not a behaviour change, and each is recorded
in `COMPONENT_PARITY.md` with its reason.

| Upstream shape | Port shape | Why |
|---|---|---|
| `Adw.Application` | `Gtk::Application` + `Adwaita.init` | `Adwaita::Application` is broken in these bindings |
| `Adw.MessageDialog` | `Adwaita::AlertDialog` | deprecated in libadwaita 1.6 |
| `Gtk.ShortcutsWindow` | `Adwaita::ShortcutsDialog` | deprecated in GTK 4.18 |
| `async` methods suspending on an `AsyncTask` | explicit callbacks | Ruby has no coroutine to resume, which is why `src/Models/AsyncTask.vala` has no file of its own: the two outcomes it existed to carry are `on_password:` and `on_cancel:` in `PasswordDialog#ask` |
| `BindingGroup` with `SYNC_CREATE \| BIDIRECTIONAL` | `update` pushes, `notify::text` pulls, behind a `@loading` guard | the Document is plain Ruby and has no GObject properties to bind |
| `ListStore` of `StringObject` + `items-changed` | plain Array + `Document#on_keywords_changed(position, removed, added)` | same three arguments, same semantics: it fires on add and remove and stays silent on an edit |
| a GtkBuilder template plus its class | one declarative Ruby class | the house style; see `.claude/skills/ruby-gtk` |

## House style

Every file: `# frozen_string_literal: true`, then `require 'adwaita'` (or
`'glib2'`/`'gio2'` where no widget is touched), then `require_relative` for
siblings. Every class carries a comment naming the upstream file it came from
and anything worth knowing. Widgets are memoized accessors configured in
`.tap` blocks and assembled in one `build`. `.rubocop.yml` plus the custom
cops in `cops/` are enforced: no `return`, no modifier `if`, no conditional
assignment, `tap` where it applies.

## Round log

**Round 1** — the window, the editor page, the two dialogs it had, the primary
menu, the drop overlay, the details and keyword lists, and a pure-Ruby PDF
parser and incremental-update writer. No translations, no tests, no data
directory, no password dialog, no thumbnail.

**Round 2** — closed, with evidence:

- `PasswordDialog`, and the standard security handler under it, so an
  encrypted PDF opens (`/R` 2 to 6, user and owner passwords, re-encrypted on
  save);
- `cached_file`: the original is copied into `$TMPDIR/copies` and the copy is
  what gets parsed, mutated and written out, so a failed save cannot damage
  the only copy a user has;
- the XMP write-back, for files that carry a packet;
- the window title follows `document.title` and tracks edits to it;
- `Window#save_selected` saves the managers the dialog returned;
- the page-count row hides when the count is zero;
- upstream's five bundled symbolic icons and the hicolor application icons,
  installed and registered, with upstream's icon names back in `date_row.rb`
  and `keyword_row.rb`;
- `Adw.TimedAnimation` at 200 ms `EASE_IN_OUT_SINE`, in place of ten linear
  `GLib::Timeout` ticks;
- the `document-view-drop` class, the `editor` action group,
  `accessible-role=presentation` on the welcome icon;
- the keyword list's items-changed subscription, its zero-to-one focus branch,
  and row-level editing instead of a full rebuild on delete;
- `DateRow` keeps the recorded time of day when a calendar day is picked;
- `--help` documents both flags;
- the whole translation layer: `po/` from upstream, the `gettext` gem, the
  domain bound at startup, 96 keys marked, the ten shortcut strings with
  `msgctxt "shortcut window"`, `translator_credits`, and `.mo` per language
  compiled and installed by the flake;
- the desktop entry, the AppStream metainfo, the GSettings schema and the
  Nautilus extension, with `msgfmt --desktop` and `--xml` merging the
  translations at install;
- the port's own spec suite: 130 examples over the date parser, the keyword
  round-trip, the `/Encrypt /P` bit map, the incremental-update writer, the
  security handler against four revisions, the XMP mirror and the dirty flag;
- eight excuse-shaped class comments rewritten, and the eight constructions
  that slipped past the scanner added to its pattern list.

**Still open after round 2**, in the order round 3 should take them:

1. Drive and screenshot every unit (`FINDINGS.md` §8). Blocked on a display,
   which is a one-line flake change.
2. `DocumentThumbnail` + `Thumbnailer` (`FINDINGS.md` §1).
3. The three widget-level guards `TEST_PARITY.md` lists as owed, which need
   (1) first.
4. `data/*.service.in`, for D-Bus activation.
