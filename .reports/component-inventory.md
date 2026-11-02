# Paper Clip — upstream component inventory

Paper Clip (`io.github.diegoivan.pdf_metadata_editor`) is a GNOME utility that
opens a single PDF, shows its metadata in an Adwaita preferences form, lets you
edit the editable properties (title, author, creation software, subject,
conversion software, creation/modification date, keywords) and writes them back
to the PDF — to the original file or to a new one. Non-editable properties are
listed read-only. Documents are opened from a file dialog, from the command
line, from a Nautilus menu entry, or by drag-and-drop onto the window.

Upstream language: **Vala** (GTK4 + libadwaita 1.x, GtkBuilder `.ui` templates,
Poppler for PDF, Exempi for XMP). Upstream ref: `origin/main`.

The `ruby` branch today holds **3** `.rb` files: `lib/paper_clip.rb`,
`lib/paper_clip/application.rb` (a blank Adwaita window with a "not written yet"
status page) and `lib/paper/clip/rb/version.rb`. Every component below is
therefore **absent** except the application shell, which exists only as a
skeleton.

## Naming

House rule is one upstream source file to one `lib/<thing>.rb`. Upstream splits
most components across a `.vala` class and a `src/gtk/*.ui` template; the two
halves union into a single port file. Upstream's `PaperClip.` namespace becomes
Ruby's `PaperClip` module, so files live under `lib/paper_clip/`.

---

## src/application.vala — the application object

| Widget | × | CSS | Signals / actions | Notes |
|---|---:|---|---|---|
| `Adw.AboutDialog` | 1 | — | — | app icon, "Paper Clip", © 2023-2024 Diego Iván M.E, developer Diego Iván M.E, artist Brage Fuglseth, issue URL, GPL-3.0, `translator_credits`, version, website |
| (no widget) | — | — | `app.about`, `app.shortcuts`, `app.query-quit`, `app.new-window` | accels: `<Ctrl>question`, `<Ctrl>q`, `<Ctrl>n` |

Behaviour that is part of the component: `HANDLES_OPEN` flag and the `open()`
override (each PDF argument gets its own window; non-PDF content types are
rejected with a `critical`); `--new-window` / `-w` and `--version` / `-v`
command-line options, with `--new-window` activating the action on an already
running instance; gettext setup; `Xmp.init` / `Xmp.terminate` at startup and
shutdown; `query-quit` collecting every toplevel window whose
`DocumentManager.changed` is true and routing them through one
`SaveChangesDialog`; `generate_debug_info` building the About dialog's debug
text from GTK/libadwaita/Poppler/Exempi/GdkPixbuf versions, Flatpak detection
and `PRETTY_NAME`.

→ `lib/paper_clip/application.rb` (**exists as a skeleton**: Gtk::Application +
Adwaita window + status page; no actions, no accels, no About dialog, no
command-line handling, no multi-window)

→ `lib/paper_clip/about_dialog.rb` (**absent**) — the About dialog and its
debug-info text are enough content to be their own file.

→ `lib/paper_clip/main.rb` (**absent**) — upstream `src/main.vala`; the port's
one-expression launcher, `PaperClip::Application.new.build.run`.

---

## src/window.vala + src/window.ui — the main window

| Widget | × | CSS | Signals / actions | Notes |
|---|---:|---|---|---|
| `Adw.ApplicationWindow` | 1 | — | `close-request` → `on_close_request` | 600×500 default, 350×320 minimum, title "Paper Clip" |
| `Adw.ToolbarView` | 1 | — | — | top bar is a vertical `Gtk.Box` |
| `Gtk.Box` | 3 | — | — | toolbar box; welcome box (vertical, spacing 15, valign center) |
| `Adw.HeaderBar` | 1 | — | — | id `header_bar` |
| `Gtk.Button` | 1 | — | `win.open` | tooltip "Select a File" |
| `Adw.ButtonContent` | 1 | — | — | `document-open-symbolic` + label "Open" |
| `Gtk.MenuButton` | 1 | — | menu-model `primary_menu` | `open-menu-symbolic`; popped up by `win.main-menu` |
| `Gtk.ProgressBar` | 1 | `osd` | — | hexpand, starts at opacity 0; pulsed while opening, animated 0→1 on save, faded out after |
| `Adw.ToastOverlay` | 1 | — | — | hosts the decrypt-failure toast |
| `PaperClip.DropOverlay` | 1 | — | — | `overlayed` = `Adw.Bin`, `child` = the stack |
| `Gtk.Stack` | 1 | — | — | crossfade; pages `empty` and `editor` |
| `Adw.Clamp` | 1 | — | — | id `welcome_clamp`, wraps the empty state |
| `Gtk.Image` | 1 | `icon-dropshadow` | — | app icon, pixel-size 128, `presentation` role |
| `Gtk.Label` | 2 | `title-1` (1st only) | — | "Open a Document", "Drag and drop a PDF file here" |
| `PaperClip.DocumentView` | 1 | — | — | the `editor` stack page |
| `Gtk.ShortcutController` | 1 | — | — | controller, not a widget |
| `Gtk.Shortcut` | 3 | — | `win.open`, `window.close`, `win.main-menu` | `<Control>o`, `<Control>w`, `F10` |
| `Gtk.DropTarget` | 1 | — | `drop` → `on_file_dropped` | controller on the stack; `COPY`, accepts `GFile` |
| `Gtk.FileDialog` | 2 | — | — | open and save-as, both with a `Gtk.FileFilter` named "PDF" for `application/pdf` |
| `Adw.Toast` | 1 | — | — | "Failed to open the document. The provided password is incorrect." |

Window actions: `win.open`, `win.open-with`, `win.save`, `win.save-as`,
`win.main-menu`. `save`, `save-as` and `open-with` start disabled and are
enabled once a document loads.

Non-widget behaviour that must port: the `WindowState` enum
(`NONE`, `OPENING_FILE`, `CLOSING`, `OPENING_DROPPED`) and `proceed_with_state`,
which is what makes "you have unsaved changes" interrupt an open/close and then
resume it; the dropped-file content-type check; `Adw.TimedAnimation` +
`Adw.PropertyAnimationTarget` on the progress bar's `fraction` and `opacity`
(`EASE_IN_OUT_SINE`, 200 ms); encrypted documents falling through to
`PasswordDialog`.

→ `lib/paper_clip/window.rb` (**absent**)
→ `lib/paper_clip/window_state.rb` (**absent**) — or a constant set inside `window.rb`.

### Primary menu (`src/window.ui`, `<menu id="primary_menu">`)

Three sections, six items: `_New Window` (`app.new-window`); `_Save`
(`win.save`, `<control>s`, hidden-when action-disabled), `Save _As…`
(`win.save-as`, `<control><shift>s`, hidden-when action-disabled), `Open _With…`
(`win.open-with`, hidden-when action-disabled); `_Keyboard Shortcuts`
(`app.shortcuts`), `_About Paper Clip` (`app.about`).

→ `lib/paper_clip/primary_menu.rb` (**absent**) — a `Gio::Menu` builder.

---

## src/DocumentView.vala + src/gtk/document-view.ui — the editor page

| Widget | × | CSS | Signals / actions | Notes |
|---|---:|---|---|---|
| `Adw.Bin` | 1 | — | — | the template root |
| `Gtk.ScrolledWindow` | 1 | — | — | propagates natural height and width; `vadjustment.value = 0` on each new document |
| `Adw.Clamp` | 1 | `document-view-drop` | — | id `content_clamp` |
| `Gtk.Box` | 1 | — | — | vertical, spacing 18, margins 12/24/12 |
| `PaperClip.DocumentThumbnail` | 1 | — | — | margin-top 12 |
| `Gtk.Label` | 1 | `title-1`, `long-filename` (dynamic) | — | id `title_label`; the basename. `long-filename` added when basename > 45 chars **and** contains a space; `ellipsize = END` when > 21 chars and contains no space; both reset per document |
| `Adw.PreferencesGroup` | 2 | — | — | the editable properties group; "Non-Editable Properties" group |
| `Adw.EntryRow` | 5 | — | — | Title, Author, Creation Software, Subject, Conversion Software |
| `PaperClip.DateRow` | 2 | — | — | Creation Date, Modification Date |
| `PaperClip.KeywordList` | 1 | — | — | |
| `PaperClip.DetailsList` | 1 | — | — | inside the details group |
| `Gtk.ShortcutController` | 1 | — | — | controller |
| `Gtk.Shortcut` | 2 | — | `win.save`, `win.save-as` | `<Control>s`, `<Control><Shift>s` |
| `Gtk.FileLauncher` | 1 | — | — | `always_ask`, bound to `document.original-file`; drives `win.open-with` |

A `GLib.BindingGroup` binds the document bidirectionally to the five entry rows
and the two date rows and syncs `document.title` to the window title. The port
has no `BindingGroup`, so this becomes explicit two-way wiring: row
`notify::text` / date change writes the document, and setting the document
refreshes the rows.

Installs an empty `editor` action group (upstream vestige; nothing uses it).

→ `lib/paper_clip/document_view.rb` (**absent**)

---

## src/DateRow.vala + src/gtk/date-row.ui — a date property row

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adw.ActionRow` | 1 | — | — | subtitle is the date as `%x`, or "No date set" when nil |
| `Gtk.Button` | 3 | `flat` (1st) | `clicked` → `on_clear_button_clicked`, `on_today_button_clicked`, `on_tomorrow_button_clicked` | clear (suffix, `entry-clear-symbolic`, tooltip "Remove Date"); "Today"; "Tomorrow" |
| `Gtk.MenuButton` | 1 | `flat` | — | suffix, tooltip "Show Calendar" |
| `Gtk.Popover` | 1 | — | — | id `calendar_popover` |
| `Gtk.Box` | 2 | `linked` (2nd) | — | vertical spacing 6; horizontal homogeneous for the two buttons |
| `Gtk.Calendar` | 1 | — | `day-selected` → `on_day_selected` | kept in sync with the row's date (month is 0-based) |

→ `lib/paper_clip/date_row.rb` (**absent**)

---

## src/DetailsList.vala + src/gtk/details-list.ui — read-only PDF properties

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adw.Bin` | 1 | — | — | template root |
| `Gtk.ListBox` | 1 | `boxed-list` | — | valign start |
| `Adw.ActionRow` | 7 | `property` | — | Format, Layout, Duplex, Subtype, Contains JavaScript, Contains Attachments, Number of Pages; all `selectable=false` |
| `PaperClip.StringArrayRow` | 2 | — | — | Viewer Preferences, Permissions |

Conditional: the Number of Pages row is visible only when `n_pages > 0`.
JavaScript and Attachments subtitles are the translated "Yes"/"No".

→ `lib/paper_clip/details_list.rb` (**absent**)

---

## src/StringArrayRow.vala — an expandable bulleted-list row

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adw.ExpanderRow` | 1 | — | — | holds exactly one content row |
| `Gtk.ListBoxRow` | 1 | — | — | `ContentRow`, a second class in the same file |
| `Gtk.Label` | 1 | `dim-label` | — | halign start, margin-start 12, margin-top 18; text is `"• %s\n"` per array item |

→ `lib/paper_clip/string_array_row.rb` (**absent**) — both classes, per the
"component is the set of files" rule; `ContentRow` is private to it.

---

## src/KeywordList.vala + src/gtk/keyword-list.ui — the keywords group

| Widget | × | CSS | Signals / actions | Notes |
|---|---:|---|---|---|
| `Adw.PreferencesGroup` | 1 | — | — | title "Keywords" |
| `Gtk.Button` | 1 | `flat` | `keyword-list.add-keyword` | header-suffix, `list-add-symbolic`, tooltip "Add a keyword"; `visible` bound to `is-empty` inverted, so it hides while the empty state shows |
| `Gtk.ListBox` | 1 | `boxed-list` | `row-activated` → `on_row_activated` | `bind_model` over `document.keywords` |
| `Gtk.ShortcutController` | 1 | — | — | controller |
| `Gtk.Shortcut` | 1 | — | `keyword-list.add-keyword` | `<Control>Return` |
| `PaperClip.KeywordRow` | n | — | — | **repeater** — one per keyword in `document.keywords`, each titled "Keyword" |

Empty state, built in code when `document.keywords` is empty:

| Widget | × | CSS | Notes |
|---|---:|---|---|
| `Adw.PreferencesRow` | 1 | — | `activatable`, not selectable; activating it adds a keyword |
| `Gtk.CenterBox` | 1 | — | |
| `Gtk.Label` | 1 | — | "Add Keyword", centered, wrap, 12px top/bottom margins |
| `Gtk.Image` | 1 | — | `list-add-symbolic`, halign end, hexpand, margin-end 12 |

Action group `keyword-list` with one action, `add-keyword`. Focus behaviour is
part of the component: adding a keyword focuses the newly appended row, and
going from zero to one keyword focuses the first child.

→ `lib/paper_clip/keyword_list.rb` (**absent**)

---

## src/KeywordRow.vala — one editable keyword

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adw.EntryRow` | 1 | — | — | focusable; text bound bidirectionally to the keyword's `str` |
| `Gtk.Button` | 1 | `flat` | `clicked` → `on_delete_clicked` | prefix, `cross-symbolic`, valign center, tooltip "Delete Keyword" |

→ `lib/paper_clip/keyword_row.rb` (**absent**)

---

## src/DropOverlay.vala — the drag-and-drop highlight

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adw.Bin` | 1 | — | — | re-exposes `child` as the overlay's child |
| `Gtk.Overlay` | 1 | — | — | built in code |
| `Gtk.Revealer` | 1 | — | — | crossfade, `can_target = false`, starts hidden; holds the `overlayed` widget |

Watches the attached `Gtk.DropTarget`'s `notify::current-drop` and, while a drop
is in flight, reveals the revealer and adds `overlay-drag-area` to the overlayed
widget — removing it again when the drop ends.

→ `lib/paper_clip/drop_overlay.rb` (**absent**)

---

## src/DocumentThumbnail.vala — the page-one preview

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adw.Bin` | 1 | — | — | |
| `Gtk.Image` | 1 | `icon-dropshadow` | — | `pixel_size = MAX_SIZE / 2`, i.e. 175 |

Renders page 0 through `Services.Thumbnailer`, then scales the texture with a
`Gtk.Snapshot`: a white background rectangle under the page (so transparent PDFs
are not invisible) and `append_scaled_texture` with `NEAREST` when upscaling and
`TRILINEAR` when downscaling. Aspect-ratio maths copied from `AdwAvatar`.
`MAX_SIZE = 350`.

→ `lib/paper_clip/document_thumbnail.rb` (**absent**)

---

## src/PasswordDialog.vala + src/gtk/password-dialog.ui — encrypted documents

| Widget | × | CSS | Signals / actions | Notes |
|---|---:|---|---|---|
| `Adw.Dialog` | 1 | — | `closed` → `on_closed` | 350×320 minimum, title "Password Dialog" |
| `Adw.ToolbarView` | 1 | — | — | |
| `Adw.HeaderBar` | 1 | — | — | `show-title = false` |
| `Adw.StatusPage` | 1 | `compact` | — | "This Document Is Encrypted", `key-symbolic`; description is the file's basename |
| `Adw.Clamp` | 1 | — | — | |
| `Gtk.Box` | 1 | — | — | vertical, spacing 12 |
| `Gtk.ListBox` | 1 | `boxed-list` | — | selection-mode none |
| `Adw.PasswordEntryRow` | 1 | — | — | title "Password" |
| `Gtk.Button` | 1 | `pill`, `suggested-action` | `dialog.success`, `clicked` → `success_task` | "Decrypt", halign center |
| `Gtk.ShortcutController` | 1 | — | — | controller, `capture` phase |
| `Gtk.Shortcut` | 2 | — | `dialog.success`, `dialog.cancel` | `Return`, `Escape` |

Action group `dialog` with `success` and `cancel`. Closing the dialog while the
task is running cancels it, and cancelling raises upstream's
`PasswordDialogError.CANCELLED`.

→ `lib/paper_clip/password_dialog.rb` (**absent**)

---

## src/SaveChangesDialog.vala + src/gtk/save-changes-dialog.ui — unsaved changes

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adw.MessageDialog` | 1 | — | — | heading "Save Changes?", body "Open documents contain unsaved changes. Changes which are not saved will be permanently lost.", default response `save`, close response `cancel` |
| responses | 3 | `destructive` (discard), `suggested` (save) | — | `_Cancel`, `_Discard`, `_Save` |
| `Gtk.ScrolledWindow` | 1 | — | — | propagates natural height and width |
| `Gtk.ListBox` | 1 | `boxed-list` | — | selection-mode none |
| `PaperClip.DocumentRow` | n | — | — | **repeater** — one per changed `DocumentManager` |

`selected_documents` walks the list box and returns the checked rows, so the
dialog answers both "what did you choose" and "which of these documents".
Response maps to the `SaveChangesResponse` enum (`CANCEL`, `DISCARD`, `SAVE`).

→ `lib/paper_clip/save_changes_dialog.rb` (**absent**)

### `PaperClip.DocumentRow` (same file)

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adw.ActionRow` | 1 | — | — | title is the document title, subtitle its basename |
| `Gtk.CheckButton` | 1 | — | `active` ↔ `selected` | prefix, valign center, starts checked |

→ `lib/paper_clip/document_row.rb` (**absent**) — upstream keeps it beside the
dialog, but it is a distinct user-facing row and earns its own file in the port.

---

## src/gtk/shortcut-window.ui — the shortcuts window

A standalone `GtkShortcutsWindow` (no backing Vala class), loaded by
`Window.shortcuts()` from the resource and shown transient for the window.

| Group | Shortcuts |
|---|---|
| General | Quit `<control>q`; New window `<control>n`; Close window `<control>w`; Keyboard Shortcuts `<control>question` |
| Editor | Open `<control>o`; Save `<control>s`; Save As… `<control><shift>s`; Add a keyword `<control>Return` |

`GtkShortcutsWindow` is deprecated in GTK 4.18 in favour of
`Adw.ShortcutsDialog`; the pilot port (`gnome-contacts-rb`
`lib/shortcuts_dialog.rb`) already uses the Adwaita replacement, so the port
should follow it and keep these eight items in these two sections.

→ `lib/paper_clip/shortcuts_dialog.rb` (**absent**)

---

## Models and services (no widgets, but the app does nothing without them)

| Upstream | What it is | Port |
|---|---|---|
| `src/Document.vala` | the PDF document: readable/writable `title`, `author`, `creator`, `subject`, `producer`, `creation_date`, `modification_date`; a `ListStore` of keywords with `add_keyword` / `remove_keyword` / comma serialisation; read-only `format`, `layout`, `print_duplex`, `subtype`, `viewer_preferences`, `permissions`, `contains_attachments`, `contains_javascript`, `n_pages`; `has_xmp`; copies the original to `$TMPDIR/copies` before opening; saves via Poppler and, when the file has XMP, mirrors producer/creator/keywords/title/CreateDate/ModifyDate/MetadataDate through Exempi | `lib/paper_clip/document.rb` (**absent**) |
| `src/Document.vala` (`StringObject`) | a mutable string box so keyword edits are observable | folded into `document.rb` (**absent**) |
| `src/Document.vala` (enum → string tables) | every translated string for layout (6 + fallback), duplex (3 + fallback), subtype (5 + fallback), viewer preferences (8), permissions (8) | `lib/paper_clip/pdf_strings.rb` (**absent**) — user-visible text, so it belongs in the inventory |
| `src/Services/DocumentManager.vala` | owns the current document and the `changed` flag that drives save enablement and the unsaved-changes dialog | `lib/paper_clip/document_manager.rb` (**absent**) |
| `src/Services/Thumbnailer.vala` | singleton; renders a Poppler page to a Cairo surface off-thread and returns a `Gdk.Texture`, downscaling via a PNG in `$TMPDIR/thumbnails` when the page area exceeds `max_size² × 2.5` | `lib/paper_clip/thumbnailer.rb` (**absent**) |
| `src/ThreadManager.vala` | one-slot `ThreadPool` wrapper that runs a closure off the main loop and resumes on idle | `lib/paper_clip/thread_manager.rb` (**absent**) — or dropped for Ruby threads plus `GLib::Idle.add` |
| `src/Models/AsyncTask.vala` | a status + `SourceFunc` pair, used only to suspend `PasswordDialog.decrypt` until a button is pressed | dropped — Ruby uses a callback; `password_dialog.rb` takes an `on_decrypt` block |
| `src/style.css` | `.long-filename` (font-size 140%), `stack:drop(active)` (no box-shadow), `.overlay-drag-area` (8px radius, 24px margin, 35% accent background) | `lib/paper_clip/style.rb` or `data/style.css` loaded by a `Gtk::CssProvider` (**absent**) |
| `data/*.gschema.xml` | the schema is **empty** — no keys, so no settings component and no `settings.rb` | n/a |
| `po/` | 18 catalogues (bg, cs, de, es, eu, fr, he, hi, hr, it, nb, nl, oc, pt_BR, ru, tr, uk, zh_CN) over `po/POTFILES`; `translator_credits` reaches the About dialog | out of scope for this step; a later translation-parity pass |

---

## Not components

- `src/meson.build`, `data/meson.build`, `po/meson.build`, `meson.build`,
  `meson_options.txt`, `vapi/Config.vapi`, `vapi/exempi-2.0.vapi`,
  `io.github.diegoivan.pdf_metadata_editor.json` — build and Flatpak plumbing.
- `src/pdf-metadata-editor.gresource.xml` — resource manifest; the port builds
  widgets in code, so only the five bundled symbolic icons
  (`entry-clear-symbolic`, `cross-symbolic`, `rich-text-symbolic`,
  `chain-link-symbolic`, `key-symbolic`) matter, and they must ship with the
  port or be swapped for stock names. `rich-text-symbolic` and
  `chain-link-symbolic` are bundled but referenced nowhere in the current UI.
- `data/icons/**`, `data/screenshots/**`, `data/*.desktop.in`,
  `data/*.metainfo.xml.in`, `data/*.service.in` — packaging assets. The desktop
  file's `new-window` action and `application/pdf` MIME association are the
  visible halves, and both are reproduced by the app's `new-window` action and
  `HANDLES_OPEN` handling.

---

## Blockers

1. **Poppler has no Ruby binding in the gtk4-era ruby-gnome family.** Every
   metadata read and write, `n_pages`, the permission and viewer-preference
   flags, the layout/duplex/subtype enums and the page render all go through
   `libpoppler-glib`. The old `poppler` gem is GTK2/Cairo-era and is not part of
   the gtk4 gem set. Options: load the `Poppler-0.18` typelib through
   `gobject-introspection` (the same mechanism the `adwaita` gem uses), or shell
   out to `pdftk`/`exiftool`/`qpdf`. This decision gates `document.rb`,
   `details_list.rb`, `document_thumbnail.rb` and `thumbnailer.rb` — the
   editable form can be built and wired against a stub document first.
2. **Exempi (XMP) has no Ruby binding at all**, and upstream ships its own
   `vapi/exempi-2.0.vapi` because there is no introspection data either. XMP
   mirroring on save (`Document.save_xmp`, `has_xmp`) cannot be ported as
   written; it needs an FFI binding to `libexempi` or an `exiftool` shell-out.
3. **`Gtk.Snapshot`-based thumbnail scaling may not be reachable.**
   `snapshot.append_color`, `append_scaled_texture` and `to_paintable` with a
   `Graphene.Rect` are thin GSK wrappers whose availability in the Ruby bindings
   is unverified. Fallback: scale with `GdkPixbuf` and composite the white
   background in Cairo, which loses the filter choice but keeps the look.
4. **`Adw.MessageDialog` is deprecated** (GTK4/libadwaita 1.6) in favour of
   `Adw.AlertDialog`, and the Ruby binding for the `<responses>` block with
   per-response appearance needs checking. The save-changes dialog likely has to
   be built from `Adwaita::AlertDialog` with responses added in code.
5. **`GLib.BindingGroup` and `bind_property` with `BIDIRECTIONAL|SYNC_CREATE`**
   are the spine of `DocumentView`, `KeywordRow` and `DocumentRow`. `GObject`
   property binding is not usefully exposed in the Ruby bindings, so all of it
   becomes explicit `notify::` handlers with a re-entrancy guard. Not a blocker,
   but it is the largest rewrite in the port and the easiest place to introduce
   an edit loop.
6. **`data/nautilus-extension/paper-clip.py` cannot be ported.** A Nautilus
   extension must be a Python or C GObject plugin loaded into the Nautilus
   process; Ruby is not a supported extension language. The file stays as
   upstream's Python, with its `Exec` path pointed at the port.
7. **`Adw.Application` and `Adw.ApplicationWindow` are broken in the Ruby
   bindings**, so the port cannot subclass the application the way upstream
   does: `Gtk::Application` plus `Adwaita::ApplicationWindow`, as the existing
   skeleton already does. Upstream overrides `activate`, `startup`, `shutdown`,
   `open` and `handle_local_options`; the port connects signals and parses
   `ARGV` itself instead.
