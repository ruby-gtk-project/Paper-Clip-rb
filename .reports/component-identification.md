# Component identification — Paper-Clip-rb, the `ruby` branch

| | |
|---|---|
| Upstream | `origin/main` @ `c4db98e0bc2b8921d78c9e3fbf3d85ad2a124bd0` |
| Port | `ruby` @ `6d05c88af0f4ad6db5fbd16c88b1d4d9a93d632c` |
| Scope | the whole app, unit by unit |

`.reports/component-inventory.md` is the **upstream** inventory and still holds.
This document is the other half: the inventory of what the `ruby` branch
actually builds, so `component-parity` has the same TSV shape from both sides.

Scans (`component-identification/scripts/component-scan.sh`):

| | Upstream rows | Port rows |
|---|---:|---:|
| total rows | 158 | 108 |
| distinct widget types | 40 | 32 |
| distinct CSS classes | 14 | 8 |
| distinct signals | 12 | 12 |
| distinct actions (literal) | 6 | 1 |
| distinct controllers | 2 | 2 |

The action stream is the least trustworthy, exactly as the skill warns: the
port installs its app-level and window-level actions from `ACTIONS` tables in
loops (`lib/paper_clip/application.rb:34`, `lib/paper_clip/window.rb:57`) and
its keyword action from constants (`lib/paper_clip/keyword_list.rb:27`), so
`app.about`, `app.shortcuts`, `app.query-quit`, `app.new-window`, `win.save`,
`win.save-as`, `win.open-with`, `win.main-menu` and
`keyword-list.add-keyword` are all installed and none of them appear in the
scan. Read the install sites, not the stream.

The same holds for two CSS classes: `long-filename` and `overlay-drag-area`
reach widgets through `DocumentView::LONG_FILENAME_CLASS`
(`lib/paper_clip/document_view.rb:43`) and `DropOverlay::DRAG_CLASS`
(`lib/paper_clip/drop_overlay.rb:19`), so the scan reports them absent and
they are present.

## File map, upstream → port

| Upstream | Port |
|---|---|
| `src/main.vala` | `lib/paper_clip/main.rb` |
| `src/application.vala` | `lib/paper_clip/application.rb` + `lib/paper_clip/about_dialog.rb` |
| `src/window.vala` + `src/window.ui` | `lib/paper_clip/window.rb` + `lib/paper_clip/window_state.rb` + `lib/paper_clip/primary_menu.rb` |
| `src/gtk/shortcut-window.ui` | `lib/paper_clip/shortcuts_dialog.rb` |
| `src/DocumentView.vala` + `src/gtk/document-view.ui` | `lib/paper_clip/document_view.rb` |
| `src/DateRow.vala` + `src/gtk/date-row.ui` | `lib/paper_clip/date_row.rb` |
| `src/DetailsList.vala` + `src/gtk/details-list.ui` | `lib/paper_clip/details_list.rb` |
| `src/StringArrayRow.vala` | `lib/paper_clip/string_array_row.rb` |
| `src/KeywordList.vala` + `src/gtk/keyword-list.ui` | `lib/paper_clip/keyword_list.rb` |
| `src/KeywordRow.vala` | `lib/paper_clip/keyword_row.rb` |
| `src/DropOverlay.vala` | `lib/paper_clip/drop_overlay.rb` |
| `src/SaveChangesDialog.vala` + `src/gtk/save-changes-dialog.ui` | `lib/paper_clip/save_changes_dialog.rb` + `lib/paper_clip/document_row.rb` |
| `src/Document.vala` | `lib/paper_clip/document.rb` + `lib/paper_clip/pdf_strings.rb` |
| `src/Services/DocumentManager.vala` | `lib/paper_clip/document_manager.rb` |
| `src/ThreadManager.vala` | `lib/paper_clip/thread_manager.rb` |
| `src/style.css` | `lib/paper_clip/style.rb` |
| **`src/PasswordDialog.vala` + `src/gtk/password-dialog.ui`** | **nothing** |
| **`src/Models/AsyncTask.vala`** | **nothing** |
| **`src/DocumentThumbnail.vala`** | **nothing** |
| **`src/Services/Thumbnailer.vala`** | **nothing** |
| **`data/io.github.diegoivan.pdf_metadata_editor.desktop.in`** | **nothing** |
| **`data/io.github.diegoivan.pdf_metadata_editor.metainfo.xml.in`** | **nothing** |
| **`data/io.github.diegoivan.pdf_metadata_editor.gschema.xml`** | **nothing** |
| **`data/io.github.diegoivan.pdf_metadata_editor.service.in`** | **nothing** |
| **`data/icons/**`, `data/nautilus-extension/paper-clip.py`** | **nothing** |
| **`src/gtk/*.svg` (5 bundled symbolic icons)** | **nothing** |
| **`po/` (18 catalogues, `LINGUAS`, `POTFILES`, `.pot`)** | **nothing** |

Six upstream files on the left of an arrow with nothing on the right is where
the largest gaps live, and they are found here rather than in any diff.

## lib/paper_clip/application.rb — the application object

| Widget | × | CSS | Signals / actions | Notes |
|---|---:|---|---|---|
| (none) | — | — | `startup`, `activate`, `open`, `destroy` on each window | `Gtk::Application` with `Adwaita.init` ahead of it |
| (no widget) | — | — | `app.about`, `app.shortcuts`, `app.query-quit`, `app.new-window` | accels `<Control>question`, `<Control>q`, `<Control>n` — built in a loop from `ACTIONS:34` |

Behaviour: `:handles_open` flag; `on_open` filters by content type and opens
one window per PDF; `query-quit` collects `@windows`' managers, routes them
through one `SaveChangesDialog`, and waits for every async save before
`app.quit`.

## lib/paper_clip/about_dialog.rb — the About dialog

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adw.AboutDialog` | 1 | — | — | icon, name, version `0.1.0`, copyright, developer name, developers (upstream + "The Ruby GTK Project"), artists, `comments`, website, issue URL (retargeted at the port's tracker), GPL-3.0, `debug_info` |

No `translator_credits`. `debug_info` lists Gtk, Libadwaita and Ruby; not
Poppler, Exempi or GdkPixbuf.

## lib/paper_clip/window.rb — the main window

| Widget | × | CSS | Signals / actions | Notes |
|---|---:|---|---|---|
| `Adw.ApplicationWindow` | 1 | — | `close-request` → `on_close_request` | 600×500 default, 350×320 minimum, title `Paper Clip` |
| `Adw.ToolbarView` | 1 | — | — | |
| `Gtk.Box` | 2 | — | — | `top_box` vertical; `welcome_box` vertical spacing 15, valign center |
| `Adw.HeaderBar` | 1 | — | — | |
| `Gtk.Button` | 1 | — | `win.open` | tooltip "Select a File" |
| `Adw.ButtonContent` | 1 | — | — | `document-open-symbolic` + "Open" |
| `Gtk.MenuButton` | 1 | — | menu-model `PrimaryMenu.build` | `open-menu-symbolic` |
| `Gtk.ProgressBar` | 1 | `osd` | — | hexpand, opacity 0 |
| `Adw.ToastOverlay` | 1 | — | — | |
| `PaperClip::DropOverlay` | 1 | — | — | overlayed = `Adwaita::Bin`, child = stack |
| `Gtk.Stack` | 1 | — | — | crossfade, `empty` + `editor` |
| `Adw.Clamp` | 1 | — | — | `welcome_clamp` |
| `Gtk.Image` | 1 | `icon-dropshadow` | — | app icon, pixel-size 128, margin-bottom 12. **No `accessible-role: presentation`** |
| `Gtk.Label` | 2 | `title-1` (1st) | — | "Open a Document", "Drag and drop a PDF file here" |
| `PaperClip::DocumentView` | 1 | — | — | |
| `Gtk.ShortcutController` | 1 | — | — | controller |
| `Gtk.Shortcut` | 3 | — | `win.open`, `window.close`, `win.main-menu` | `<Control>o`, `<Control>w`, `F10` — built in a loop from `SHORTCUTS:60` |
| `Gtk.DropTarget` | 1 | — | `drop` → `on_file_dropped` | on the stack; `:copy`, `Gio::File` |
| `Gtk.FileDialog` | 2 | — | — | open (title set to "Open a Document") and save-as, each with a `Gtk.FileFilter` "PDF" |
| `Adw.Toast` | 3 distinct texts | — | — | "Failed to open the document. It is encrypted.", "Failed to open the document.", "That file is not a PDF.", plus "Failed to save the document." |

Actions `win.open`, `win.open-with`, `win.save`, `win.save-as`,
`win.main-menu`; the last three plus `open-with` start disabled and are
enabled in `enable_document_actions:252`. `WindowState` is a four-symbol
module and `proceed_with_state:447` resumes the interrupted open/drop/close.
The progress bar is `GLib::Timeout`-driven, not `Adw.TimedAnimation`.

## lib/paper_clip/primary_menu.rb — the primary menu

Three sections, six items, from `SECTIONS:18`: `_New Window`
(`app.new-window`); `_Save` (`win.save`, `<control>s`, hidden-when
action-disabled), `Save _As…` (`win.save-as`, `<control><shift>s`,
hidden-when), `Open _With…` (`win.open-with`, hidden-when);
`_Keyboard Shortcuts` (`app.shortcuts`), `_About Paper Clip` (`app.about`).

## lib/paper_clip/shortcuts_dialog.rb — the shortcuts dialog

`Adwaita::ShortcutsDialog` with two `Adwaita::ShortcutsSection`s and **nine**
`Adwaita::ShortcutsItem`s: General = Quit, New window, Close window,
**Open menu (F10)**, Keyboard Shortcuts; Editor = Open, Save, Save As…,
Add a keyword. Dialog title "Keyboard Shortcuts".

## lib/paper_clip/document_view.rb — the editor page

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Gtk.ScrolledWindow` | 1 | — | — | the root — no `Adw.Bin` wrapper; propagates natural height/width; `vadjustment.value = 0` per document |
| `Adw.Clamp` | 1 | **none** | — | `content_clamp` |
| `Gtk.Box` | 1 | — | — | vertical 18, margins 12/12/12/24 |
| `Gtk.Label` | 1 | `title-1`, `long-filename` (dynamic) | — | basename; thresholds 45-with-space and 21-without |
| `Adw.PreferencesGroup` | 2 | — | — | properties; "Non-Editable Properties" |
| `Adw.EntryRow` | 5 | — | `notify::text` ×5 | Title, Author, Creation Software, Subject, Conversion Software — from `FIELDS:34` |
| `PaperClip::DateRow` | 2 | — | `on_change` | Creation Date, Modification Date |
| `PaperClip::KeywordList` | 1 | — | — | |
| `PaperClip::DetailsList` | 1 | — | — | |
| `Gtk.ShortcutController` | 1 | — | — | controller |
| `Gtk.Shortcut` | 2 | — | `win.save`, `win.save-as` | `<Control>s`, `<Control><Shift>s` |
| `Gtk.FileLauncher` | 1 | — | — | built per launch, `always_ask`, from `document.original_file` |

No thumbnail widget. No `editor` action group. The document → window-title
sync is not built.

## lib/paper_clip/date_row.rb — a date property row

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adw.ActionRow` | 1 | — | — | subtitle `%x` or "No date set" |
| `Gtk.Button` | 3 | `flat` (clear only) | `clicked` ×3 | clear (`edit-clear-symbolic`, "Remove Date"), "Today", "Tomorrow" |
| `Gtk.MenuButton` | 1 | `flat` | — | `x-office-calendar-symbolic`, "Show Calendar" |
| `Gtk.Popover` | 1 | — | — | |
| `Gtk.Box` | 2 | `linked` (2nd) | — | vertical 6; horizontal homogeneous |
| `Gtk.Calendar` | 1 | — | `day-selected` | `@syncing` re-entrancy guard; month 0-based |

## lib/paper_clip/details_list.rb — read-only properties

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Gtk.ListBox` | 1 | `boxed-list` | — | the root — no `Adw.Bin`; valign start, selection none |
| `Adw.ActionRow` | 7 (repeater over `TITLES:21`) | `property` | — | Format, Layout, Duplex, Subtype, Contains JavaScript, Contains Attachments, Number of Pages |
| `PaperClip::StringArrayRow` | 2 | — | — | Viewer Preferences, Permissions |

Conditional: **none**. The page-count row is always visible.

## lib/paper_clip/string_array_row.rb — expandable bulleted row

`Adw.ExpanderRow` (1) holding one `ContentRow < Gtk.ListBoxRow` (1) holding a
`Gtk.Label` with `dim-label`, halign start, margin-start 12, margin-top 18,
text `"• %s\n"` per item.

## lib/paper_clip/keyword_list.rb — the keywords group

| Widget | × | CSS | Signals / actions | Notes |
|---|---:|---|---|---|
| `Adw.PreferencesGroup` | 1 | — | — | title "Keywords" |
| `Gtk.Button` | 1 | `flat` | `keyword-list.add-keyword` | header-suffix, `list-add-symbolic`, "Add a keyword"; `visible` recomputed in `refresh:152` |
| `Gtk.ListBox` | 1 | `boxed-list` | `row-activated` | rebuilt from the plain keyword array, not `bind_model` |
| `Gtk.ShortcutController` + `Gtk.Shortcut` | 1 + 1 | — | `keyword-list.add-keyword` | `<Control>Return` |
| `PaperClip::KeywordRow` | n (repeater) | — | — | one per keyword |
| `Adw.PreferencesRow` | 1 | — | activatable | empty state |
| `Gtk.CenterBox` | 1 | — | — | |
| `Gtk.Label` | 1 | — | — | "Add Keyword", centred, wrap, 12px margins |
| `Gtk.Image` | 1 | — | — | `list-add-symbolic`, halign end, hexpand, margin-end 12 |

Focus: the newly appended row is focused after an add. There is no
zero-to-one "focus the first child" branch and no `items-changed` subscription.

## lib/paper_clip/keyword_row.rb — one editable keyword

`Adw.EntryRow` (1), focusable, title "Keyword", `notify::text` → callback; a
prefix `Gtk.Button` with `flat`, `window-close-symbolic` (**not** upstream's
bundled `cross-symbolic`), valign center, tooltip "Delete Keyword",
`clicked` → callback.

## lib/paper_clip/drop_overlay.rb — the drag highlight

`Adw.Bin` (1) → `Gtk.Overlay` (1) → `Gtk.Revealer` (1, crossfade,
`can_target = false`, `visible = false`). Watches the drop target's
`notify::current-drop` and adds/removes `overlay-drag-area` on the overlaid
widget.

## lib/paper_clip/save_changes_dialog.rb + document_row.rb

`Adw.AlertDialog` (1) — heading "Save Changes?", body upstream's, responses
`_Cancel` / `_Discard` (destructive) / `_Save` (suggested), default `save`,
close `cancel`, `response` signal; `extra_child` is a
`Gtk.ScrolledWindow` (1) holding a `Gtk.ListBox` (1, `boxed-list`) of
`DocumentRow`s (n, repeater). `DocumentRow` is an `Adw.ActionRow` with a
prefix `Gtk.CheckButton` checked by default, title = document title falling
back to the basename, subtitle = basename.

## Models and services

| Port file | What it builds |
|---|---|
| `lib/paper_clip/document.rb` | a hand-written PDF parser/writer: object scan, `/Type /ObjStm` inflate, trailer merge, incremental-update append; Info accessors, keyword array, `has_xmp?`, `n_pages`, `contains_javascript?`, `contains_attachments?`; raises `EncryptedError` rather than opening an encrypted file; no `cached_file` copy; no XMP write-back |
| `lib/paper_clip/pdf_strings.rb` | layout (6 + fallback), duplex (3 + fallback), subtype (5 + fallback), viewer preferences (7 + "No preferences"), permissions (8), "Unknown" |
| `lib/paper_clip/document_manager.rb` | the open document and the dirty flag |
| `lib/paper_clip/thread_manager.rb` | one worker thread, a `Queue`, `GLib::Idle` delivery |
| `lib/paper_clip/style.rb` | the three CSS rules as a heredoc on a `Gtk::CssProvider` at `PRIORITY_APPLICATION` |
| `lib/paper_clip/window_state.rb` | the four-symbol state module |
| `lib/paper_clip/main.rb` | `-v/--version`, `-w/--new-window` (via `--gapplication-action`) |

## Components that exist upstream and are built nowhere in the port

- the password dialog and everything in it (`Adw.Dialog`, `Adw.ToolbarView`,
  `Adw.HeaderBar`, `Adw.StatusPage.compact`, `Adw.Clamp`, `Gtk.Box`,
  `Gtk.ListBox.boxed-list`, `Adw.PasswordEntryRow`,
  `Gtk.Button.pill.suggested-action`, a capture-phase `Gtk.ShortcutController`
  with `Return` and `Escape`, the `dialog` action group, the `closed` signal);
- the page-one thumbnail (`Adw.Bin`, `Gtk.Image.icon-dropshadow`) and the
  `Thumbnailer` behind it;
- `Adw.VERSION` in the debug block;
- the `document-view-drop` class on the editor clamp;
- the `editor` action group on the editor page;
- the document-title → window-title binding;
- the page-count row's conditional visibility;
- every packaging component: desktop entry and its `new-window` action,
  AppStream metainfo, GSettings schema, D-Bus service file, the app icons, the
  five bundled symbolic icons, the Nautilus extension;
- the entire `po/` tree.
