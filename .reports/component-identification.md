# Component identification — Paper Clip

| | |
|---|---|
| Upstream | `origin/main` @ `c4db98e0bc2b8921d78c9e3fbf3d85ad2a124bd0` (2025-04-28) |
| Port | `ruby` branch, this audit |
| Upstream units (template roots / widget-owning classes) | **13** |
| Port units | **12** |
| Units with no port counterpart | **2** (`DocumentThumbnail`, `Services/Thumbnailer`) |

The unit is the file, as the skill defines it: one upstream source file (plus the
`.ui` template it owns) against one `lib/paper_clip/*.rb`.

## Upstream inventory

### `src/window.ui` + `src/window.vala` — the application window
- `AdwApplicationWindow` 600×500, min 350×320, title `Paper Clip`, `close-request` → `on_close_request`
- `AdwToolbarView` → top: `GtkBox(vertical)` holding `AdwHeaderBar#header_bar` and `GtkProgressBar#progress_bar` (`.osd`, opacity 0)
- header start: `GtkButton` action `win.open`, tooltip *Select a File*, child `AdwButtonContent` icon `document-open-symbolic` label *Open*
- header end: `GtkMenuButton#menu_button` icon `open-menu-symbolic`, menu `primary_menu`
- content: `AdwToastOverlay#toast_overlay` → `PaperClipDropOverlay#drop_overlay` (overlayed `AdwBin#overlay_bin`) → `GtkStack#view_stack` (crossfade)
  - page `empty`: `AdwClamp#welcome_clamp` → `GtkBox#welcome_status` (vertical, 15, valign center) → `GtkImage` (`icon-dropshadow`, pixel-size 128, margin-bottom 12, accessible-role presentation), `GtkLabel` *Open a Document* (`.title-1`), `GtkLabel` *Drag and drop a PDF file here*
  - page `editor`: `PaperClipDocumentView#doc_view`
- `GtkShortcutController`: `<Control>o`→`win.open`, `<Control>w`→`window.close`, `F10`→`win.main-menu`
- actions installed on `win`: `open`, `open-with`, `save`, `save-as`, `main-menu`; `save`/`save-as`/`open-with` start disabled
- controller: `GtkDropTarget(File, COPY)` on `view_stack`, `drop` → `on_file_dropped`
- `menu primary_menu`, three sections: *_New Window* `app.new-window`; *_Save* `win.save` `<control>s` hidden-when action-disabled, *Save _As…* `win.save-as` `<control><shift>s` hidden-when action-disabled, *Open _With…* `win.open-with` hidden-when action-disabled; *_Keyboard Shortcuts* `app.shortcuts`, *_About Paper Clip* `app.about`
- error state: one `AdwToast` — *Failed to open the document. The provided password is incorrect.*

### `src/application.vala` — `Adw.Application`
- app id `io.github.diegoivan.pdf_metadata_editor`, flags `HANDLES_OPEN`
- actions `about`, `shortcuts`, `query-quit`, `new-window`; accels `<Ctrl>question`, `<Ctrl>q`, `<Ctrl>n`
- main options `--new-window`/`-w` (*Open a new window*), `--version`/`-v` (*Print version information and exit*)
- `open()` — one window per PDF, non-PDFs logged and skipped
- `AdwAboutDialog` with icon, name, copyright, developer, developers, artists, issue url, GPL-3.0, `translator_credits`, version, website, `debug_info`
- `startup`/`shutdown` — `Xmp.init` / `Xmp.terminate`
- `query-quit` — collects every dirty `DocumentManager`, one `SaveChangesDialog`, saves the ticked ones

### `src/DocumentView.vala` + `src/gtk/document-view.ui` — the editor page
- `AdwBin` → `GtkScrolledWindow#scrolled_window` (propagate natural h/w) → `AdwClamp#content_clamp` (`.document-view-drop`) → `GtkBox(vertical,18, margins 12/24/12)`
- children in order: **`PaperClipDocumentThumbnail#document_thumbnail` (margin-top 12)**, `GtkLabel#title_label` (`.title-1`, wrap, justify center, hexpand), `AdwPreferencesGroup#properties_group`, `PaperClipKeywordList#keyword_list`, `AdwPreferencesGroup#details_group` (*Non-Editable Properties*) → `PaperClipDetailsList#details_list`
- `properties_group`: `AdwEntryRow` × 5 — *Title*, *Author*, *Creation Software*, *Subject*, *Conversion Software* — then `PaperClipDateRow` × 2 — *Creation Date*, *Modification Date*
- `GtkShortcutController`: `<Control>s`→`win.save`, `<Control><Shift>s`→`win.save-as`
- `BindingGroup` of 8 bidirectional/sync-create bindings + `document.title`→`root.title`
- `insert_action_group("editor", SimpleActionGroup)` — empty namespace
- `Gtk.FileLauncher(always_ask=true)` for *Open With*
- `.long-filename` applied above 45 chars with a space; `ellipsize=END` above 21 chars without one

### `src/DocumentThumbnail.vala` — page-one preview
- `Adw.Bin` → `GtkImage` with `.icon-dropshadow`, `pixel_size = 175`
- `MAX_SIZE = 350`; `Gtk.Snapshot` white `append_color` rectangle under `append_scaled_texture`, filter `NEAREST` when upscaling else `TRILINEAR`; `compute_scaled_size` from AdwAvatar
- destructor clears the image

### `src/Services/Thumbnailer.vala` — off-thread renderer
- singleton; `create_thumbnail(page, basename)` renders a Cairo ARGB32 surface on `ThreadManager`
- over `max_size² × area_threshold`: writes PNG to `$TMPDIR/thumbnails/<basename>.png`, reloads via `Gdk::Pixbuf.from_file_at_size` at the first 0.1-step scale that clears the budget
- under it: `Gdk.MemoryTexture` from a sized copy, endian-chosen `MemoryFormat`
- `errordomain ThumbnailError { FAILED_EXPORT, FAILED_TO_CACHE }`

### `src/DetailsList.vala` + `src/gtk/details-list.ui`
- `AdwBin` → `GtkListBox` (`.boxed-list`, valign start)
- `AdwActionRow` × 7, each `selectable=false` + `.property`: *Format*, *Layout*, *Duplex*, *Subtype*, *Contains JavaScript*, *Contains Attachments*, *Number of Pages*
- `PaperClipStringArrayRow` × 2: *Viewer Preferences*, *Permissions*
- *Yes* / *No* for the two booleans; pages row hidden when `n_pages == 0`

### `src/StringArrayRow.vala`
- `Adw.ExpanderRow` + inner `ContentRow : Gtk.ListBoxRow` → `GtkLabel` (`.dim-label`, halign START, margin-start 12, margin-top 18); contents are `"• %s\n"` per entry

### `src/DateRow.vala` + `src/gtk/date-row.ui`
- `Adw.ActionRow`; suffix `GtkButton` icon `entry-clear-symbolic` (`.flat`, tooltip *Remove Date*) → `on_clear_button_clicked`
- suffix `GtkMenuButton` (`.flat`, tooltip *Show Calendar*) → `GtkPopover#calendar_popover` → `GtkBox(vertical,6)` → `GtkCalendar#calendar` (`day-selected`) + `GtkBox(.linked, homogeneous)` with *Today* / *Tomorrow* buttons
- subtitle is `date.format("%x")` or *No date set*

### `src/KeywordList.vala` + `src/gtk/keyword-list.ui`
- `Adw.PreferencesGroup` titled *Keywords*
- header-suffix `GtkButton#add_button` icon `list-add-symbolic` (`.flat`, tooltip *Add a keyword*), action `keyword-list.add-keyword`, `visible` bound to `is-empty` inverted
- `GtkListBox#listbox` (`.boxed-list`), `row-activated` → `on_row_activated`
- `GtkShortcutController`: `<Control>Return` → `keyword-list.add-keyword`
- action group `keyword-list` with `add-keyword`
- **empty state**: `AdwPreferencesRow` (activatable, not selectable) → `GtkCenterBox` with `GtkImage` `list-add-symbolic` (halign END, hexpand, margin-end 12) and `GtkLabel` *Add Keyword* (justify center, wrap, margins 12)
- focus rules: last row grabs focus on every change; first row when the list becomes one row long

### `src/KeywordRow.vala`
- `Adw.EntryRow`, `focusable`, title *Keyword*, prefix `GtkButton` icon `cross-symbolic` (`.flat`, tooltip *Delete Keyword*)

### `src/DropOverlay.vala`
- `Adw.Bin` → `GtkOverlay` + overlaid `GtkRevealer` (`can_target=false`, `visible=false`, CROSSFADE)
- watches `notify::current-drop`; adds/removes `.overlay-drag-area` on the overlaid widget

### `src/PasswordDialog.vala` + `src/gtk/password-dialog.ui`
- `Adw.Dialog` 350×320, title *Password Dialog*, `closed` → `on_closed`
- `AdwToolbarView` → `AdwHeaderBar` (`show-title=false`) → `AdwStatusPage#status_page` (`.compact`, icon `key-symbolic`, title *This Document Is Encrypted*, description = basename)
- `AdwClamp` → `GtkBox(vertical,12)` → `GtkListBox` (`.boxed-list`, selection none) → `AdwPasswordEntryRow#password_entry` (*Password*); `GtkButton#decrypt_button` *Decrypt* (`.pill .suggested-action`, action `dialog.success`)
- `GtkShortcutController` **capture phase**: `Return`→`dialog.success`, `Escape`→`dialog.cancel`
- action group `dialog` with `success`, `cancel`; `errordomain PasswordDialogError { CANCELLED }`

### `src/SaveChangesDialog.vala` + `src/gtk/save-changes-dialog.ui`
- `Adw.MessageDialog`, heading *Save Changes?*, body *Open documents contain unsaved changes…*, default `save`, close `cancel`
- responses `_Cancel`, `_Discard` (destructive), `_Save` (suggested)
- `GtkScrolledWindow` → `GtkListBox#documents_listbox` (`.boxed-list`, selection none)
- `DocumentRow : Adw.ActionRow` with prefix `GtkCheckButton` (valign center) bound to `selected`, title = `document.title`, subtitle = basename, checked by default
- `enum SaveChangesResponse { CANCEL, DISCARD, SAVE }`

### `src/gtk/shortcut-window.ui`
- `GtkShortcutsWindow#shortcut_window`, modal, one `GtkShortcutsSection` (`max-height=10`), two groups, all strings `context="shortcut window"`
- *General*: *Quit* `<control>q`, *New window* `<control>n`, *Close window* `<control>w`, *Keyboard Shortcuts* `<control>question`
- *Editor*: *Open* `<control>o`, *Save* `<control>s`, *Save As…* `<control><shift>s`, *Add a keyword* `<control>Return`

### Non-widget units
- `src/Document.vala` (+ `StringObject`, `XmpError`), `src/Services/DocumentManager.vala`, `src/ThreadManager.vala`, `src/Models/AsyncTask.vala`, `src/style.css` (3 rules: `.long-filename`, `stack:drop(active)`, `.overlay-drag-area`)
- `data/*.desktop.in`, `data/*.metainfo.xml.in`, `data/*.gschema.xml` (empty schema), **`data/*.service.in`** (D-Bus activation), `data/nautilus-extension/paper-clip.py`
- `data/meson.build` declares **three build-system tests**: `desktop-file-validate`, `appstreamcli validate`, `glib-compile-schemas --strict --dry-run`

## Port inventory

| Upstream unit | Port file |
|---|---|
| `src/window.ui` + `src/window.vala` | `lib/paper_clip/window.rb` |
| `menu primary_menu` (in `window.ui`) | `lib/paper_clip/primary_menu.rb` |
| `src/application.vala` (app object) | `lib/paper_clip/application.rb` |
| `src/application.vala` (`on_about_action`, `generate_debug_info`) | `lib/paper_clip/about_dialog.rb` |
| `src/main.vala` + option table | `lib/paper_clip/main.rb` |
| `src/DocumentView.vala` + `.ui` | `lib/paper_clip/document_view.rb` |
| **`src/DocumentThumbnail.vala`** | **— none —** |
| **`src/Services/Thumbnailer.vala`** | **— none —** |
| `src/DetailsList.vala` + `.ui` | `lib/paper_clip/details_list.rb` |
| `src/StringArrayRow.vala` (both classes) | `lib/paper_clip/string_array_row.rb` |
| `src/DateRow.vala` + `.ui` | `lib/paper_clip/date_row.rb` |
| `src/KeywordList.vala` + `.ui` | `lib/paper_clip/keyword_list.rb` |
| `src/KeywordRow.vala` | `lib/paper_clip/keyword_row.rb` |
| `src/DropOverlay.vala` | `lib/paper_clip/drop_overlay.rb` |
| `src/PasswordDialog.vala` + `.ui` | `lib/paper_clip/password_dialog.rb` |
| `src/SaveChangesDialog.vala` + `.ui` | `lib/paper_clip/save_changes_dialog.rb` |
| `PaperClip.DocumentRow` (same file) | `lib/paper_clip/document_row.rb` |
| `src/gtk/shortcut-window.ui` | `lib/paper_clip/shortcuts_dialog.rb` |
| `src/Document.vala` | `lib/paper_clip/document.rb` (+ `pdf_strings.rb`, `pdf_crypt.rb`, `xmp_packet.rb`) |
| `src/Services/DocumentManager.vala` | `lib/paper_clip/document_manager.rb` |
| `src/ThreadManager.vala` | `lib/paper_clip/thread_manager.rb` |
| `src/Models/AsyncTask.vala` | *folded into the dialogs' callbacks* |
| `WindowState` enum | `lib/paper_clip/window_state.rb` |
| `src/style.css` | `lib/paper_clip/style.rb` |
| `Intl.*` in `application.vala` | `lib/paper_clip/translations.rb` |
| `data/*.desktop.in`, `*.metainfo.xml.in`, `*.gschema.xml`, `nautilus-extension/` | present under `data/` |
| **`data/*.service.in`** | **— none —** |
| icons from `pdf-metadata-editor.gresource.xml` | `data/icons/hicolor/scalable/actions/*.svg` (all five) |

## Identification-level gaps

1. **`DocumentThumbnail` has no port unit.** The editor page's first child is absent.
2. **`Services/Thumbnailer` has no port unit.** No renderer, no `$TMPDIR/thumbnails` cache, no `ThumbnailError`.
3. **`data/io.github.diegoivan.pdf_metadata_editor.service.in` has no port unit.** Upstream installs a D-Bus service file naming `--gapplication-service`; nothing in `data/` or `flake.nix` installs one.
4. **No unit was identified by running the app.** `require "adwaita"` raises `Gtk::InitError` here (no display, no `Xvfb` in the closure), so every facet above on the port side is read from source, not observed. The CSS-class and signal columns are therefore claims, not results.
