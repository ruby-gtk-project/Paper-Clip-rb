# Component inventory — Paper Clip

| | |
|---|---|
| Upstream | `origin/main` (`src/*.vala` + `src/gtk/*.ui` + `src/window.ui`) |
| Port | `ruby` branch, `lib/paper_clip/*.rb` |
| User-facing components identified | **26** |
| Already present in `lib/` | **24** |
| Missing | **2** (`DocumentThumbnail`, `Services/Thumbnailer`) |

Read with `.reports/component-identification.md`, which carries the per-widget
facets (types, CSS classes, signals, actions). This file is the join table: one
row per component, naming the upstream file, the `lib/*.rb` it becomes, its kind,
and whether that file exists today.

The unit is the file as the `component-identification` skill defines it — one
upstream source file *together with* the `.ui` template it owns, against one
`lib/paper_clip/*.rb`. Upstream splits nearly every component that way, so the
`.ui` and the `.vala` are unioned before comparing.

## The inventory

Ordered as a user meets the app: application, window, editor page, the rows
inside it, then the dialogs.

| # | Upstream file(s) | Port file | Kind | Exists |
|---:|---|---|---|:--:|
| 1 | `src/main.vala` + `application.vala` option table | `lib/paper_clip/main.rb` | entry point, `--new-window` / `--version` | yes |
| 2 | `src/application.vala` | `lib/paper_clip/application.rb` | `Adw.Application`, app actions + accels | yes |
| 3 | `src/application.vala` (`on_about_action`, `generate_debug_info`) | `lib/paper_clip/about_dialog.rb` | dialog (`AdwAboutDialog`, debug info) | yes |
| 4 | `src/window.ui` + `src/window.vala` | `lib/paper_clip/window.rb` | window (`AdwApplicationWindow`) | yes |
| 5 | `src/window.ui` — `empty` stack page | `lib/paper_clip/window.rb` (`welcome_*`) | empty state (icon + *Open a Document*) | yes |
| 6 | `src/window.ui` — progress bar + `file_save_animation` | `lib/paper_clip/window.rb` (`progress_bar`) | progress / feedback (`.osd`) | yes |
| 7 | `src/window.vala` — `load_document_to_view` toast | `lib/paper_clip/window.rb` (toast overlay) | error state (wrong-password toast) | yes |
| 8 | `src/window.ui` — `<menu id="primary_menu">` | `lib/paper_clip/primary_menu.rb` | menu (3 sections, 6 items) | yes |
| 9 | `src/window.ui` — `GtkShortcutController` | `lib/paper_clip/window.rb` (`SHORTCUTS`) | keyboard shortcuts (`<Ctrl>o/w`, `F10`) | yes |
| 10 | `src/DropOverlay.vala` | `lib/paper_clip/drop_overlay.rb` | widget (drag-over tint) | yes |
| 11 | `src/DocumentView.vala` + `src/gtk/document-view.ui` | `lib/paper_clip/document_view.rb` | page (the editor) | yes |
| 12 | `src/DocumentView.vala` — `GtkShortcutController` | `lib/paper_clip/document_view.rb` | keyboard shortcuts (`<Ctrl>S`, `<Ctrl><Shift>S`) | yes |
| 13 | **`src/DocumentThumbnail.vala`** | **`lib/paper_clip/document_thumbnail.rb`** | **widget (page-one preview)** | **no** |
| 14 | **`src/Services/Thumbnailer.vala`** | **`lib/paper_clip/thumbnailer.rb`** | **service (off-thread renderer + cache)** | **no** |
| 15 | `src/DetailsList.vala` + `src/gtk/details-list.ui` | `lib/paper_clip/details_list.rb` | widget (read-only property list) | yes |
| 16 | `src/StringArrayRow.vala` (both classes) | `lib/paper_clip/string_array_row.rb` | row (`AdwExpanderRow` + `ContentRow`) | yes |
| 17 | `src/DateRow.vala` + `src/gtk/date-row.ui` | `lib/paper_clip/date_row.rb` | row (date + calendar popover) | yes |
| 18 | `src/KeywordList.vala` + `src/gtk/keyword-list.ui` | `lib/paper_clip/keyword_list.rb` | widget (Keywords group + its action) | yes |
| 19 | `src/KeywordList.vala` — `create_default_row` | `lib/paper_clip/keyword_list.rb` | empty state (*Add Keyword* row) | yes |
| 20 | `src/KeywordRow.vala` | `lib/paper_clip/keyword_row.rb` | row (editable keyword) | yes |
| 21 | `src/PasswordDialog.vala` + `src/gtk/password-dialog.ui` | `lib/paper_clip/password_dialog.rb` | dialog (encrypted document) | yes |
| 22 | `src/SaveChangesDialog.vala` + `src/gtk/save-changes-dialog.ui` | `lib/paper_clip/save_changes_dialog.rb` | dialog (unsaved changes) | yes |
| 23 | `PaperClip.DocumentRow` (in `SaveChangesDialog.vala`) | `lib/paper_clip/document_row.rb` | row (one unsaved document) | yes |
| 24 | `src/gtk/shortcut-window.ui` | `lib/paper_clip/shortcuts_dialog.rb` | shortcuts window (2 groups, 8 entries) | yes |
| 25 | `src/style.css` | `lib/paper_clip/style.rb` | stylesheet (3 rules) | yes |
| 26 | `data/nautilus-extension/paper-clip.py` | `data/nautilus-extension/paper-clip.py` | shell integration (context-menu item) | yes |

### Non-widget units carried along

| Upstream file(s) | Port file | Kind | Exists |
|---|---|---|:--:|
| `src/Document.vala` | `lib/paper_clip/document.rb`, `pdf_strings.rb`, `pdf_crypt.rb`, `xmp_packet.rb` | model | yes |
| `src/Services/DocumentManager.vala` | `lib/paper_clip/document_manager.rb` | service (dirty tracking) | yes |
| `src/ThreadManager.vala` | `lib/paper_clip/thread_manager.rb` | service (worker) | yes |
| `src/Models/AsyncTask.vala` | folded into the dialogs' callbacks | model | n/a |
| `WindowState` enum (`src/window.vala`) | `lib/paper_clip/window_state.rb` | enum | yes |
| `Intl.*` (`src/application.vala:30-32`) | `lib/paper_clip/translations.rb` | i18n binding | yes |

## Preferences

Upstream has **no preferences dialog**. `data/io.github.diegoivan.pdf_metadata_editor.gschema.xml`
declares the schema with an empty body — no keys — so there is nothing for a
preferences page to edit and nothing for the port to persist. The port ships the
same empty schema under `data/`.

## Resources checked

- **`.ui` files** — all eight in `src/pdf-metadata-editor.gresource.xml`
  (`window.ui`, `gtk/document-view.ui`, `date-row.ui`, `details-list.ui`,
  `keyword-list.ui`, `save-changes-dialog.ui`, `shortcut-window.ui`,
  `password-dialog.ui`). No blueprint; these are raw GtkBuilder XML.
- **GResource** — also bundles `style.css` and five symbolic icons
  (`entry-clear`, `cross`, `rich-text`, `chain-link`, `key`). The port has no
  gresource; the CSS travels as a string in `style.rb` and all five icons are
  installed as files under `data/icons/hicolor/scalable/actions/`.
- **GSettings** — one schema, zero keys (see above).
- **`po/`** — `po/LINGUAS` lists 18 languages, all 18 `.po` files are present in
  the port's `po/` and compiled under `locale/`. `po/POTFILES` lists 17 sources;
  it names `*.appdata.xml.in` where the tree now has `*.metainfo.xml.in`, which
  is an upstream staleness, not a port gap.

## Gaps to close

1. **`src/DocumentThumbnail.vala` → `lib/paper_clip/document_thumbnail.rb`.**
   The editor page's first child. `AdwBin` → `GtkImage` with `.icon-dropshadow`
   at `pixel_size = MAX_SIZE / 2`, the page snapshotted over a white rectangle
   with `NEAREST` / `TRILINEAR` filtering and AdwAvatar's scaling arithmetic.
2. **`src/Services/Thumbnailer.vala` → `lib/paper_clip/thumbnailer.rb`.** The
   singleton renderer behind it: Cairo ARGB32 render on `ThreadManager`, a
   `$TMPDIR/thumbnails/<basename>.png` cache above the area budget, a
   `Gdk::MemoryTexture` below it, and `ThumbnailError`. Blocked on
   `Document#get_page_for_index`, which the port's PDF reader does not provide —
   the port parses the Info dictionary rather than rendering pages.
3. **`data/io.github.diegoivan.pdf_metadata_editor.service.in`** is not a
   user-facing component, but it is the D-Bus activation file, and nothing in
   `data/` or `flake.nix` installs one. Noted here so it is not lost.

## Method and its limits

Every facet above is read from source: upstream with
`git show origin/main:<path>`, the port by reading `lib/`. Nothing was observed
in a running app, so the "exists" column means *a port file covers that
component*, not *that component was seen on screen*. Widget-level parity —
whether the port's version of a present component carries the same CSS classes
and signals — is `component-parity`'s job, not this file's.
