# Component identification — Paper Clip

| | |
|---|---|
| Upstream | `origin/main` @ `c4db98e0bc2b8921d78c9e3fbf3d85ad2a124bd0` (2025-04-28) |
| Port | `ruby` @ `1ce848a` (re-verified; previous round was `3800624`) |
| Upstream widget units | **15** |
| Port widget units | **15** |
| Widget units with no port counterpart | **0** |
| Non-widget upstream files with no port counterpart | **3** (`COPYING`, the Flatpak manifest, `Paper-Clip.doap`) |
| Identified by running the app | **yes** — 278 checks, 18 screenshots, `nix develop --command xvfb-run -a ruby test/drive_paper_clip.rb` |

The unit is the file as the skill defines it: one upstream source file, unioned
with the `.ui` template it owns, against one `lib/paper_clip/*.rb`.

This round the port side was identified by *running*, not only by reading. The
numbers below were produced by `component-scan.sh` over
`git archive origin/main` and `git archive ruby`, then read file by file, then
checked against the driver's assertions and the eighteen screenshots under
`tmp/shots/`.

## Upstream inventory

### `src/window.ui` + `src/window.vala` — the application window
- `AdwApplicationWindow` 600×500, min 350×320, title `Paper Clip`, `close-request` → `on_close_request`
- `AdwToolbarView` → top `GtkBox(vertical)` holding `AdwHeaderBar` and `GtkProgressBar` (`.osd`, opacity 0)
- header start `GtkButton` → `win.open`, tooltip *Select a File*, child `AdwButtonContent` `document-open-symbolic` / *Open*
- header end `GtkMenuButton` `open-menu-symbolic` → `primary_menu`
- content `AdwToastOverlay` → `PaperClipDropOverlay` (overlaid `AdwBin`) → `GtkStack` (crossfade)
  - page `empty`: `AdwClamp` → `GtkBox(vertical,15,center)` → `GtkImage` (`.icon-dropshadow`, 128, margin-bottom 12, role presentation), `GtkLabel` *Open a Document* (`.title-1`), `GtkLabel` *Drag and drop a PDF file here*
  - page `editor`: `PaperClipDocumentView`
- `GtkShortcutController`: `<Control>o`→`win.open`, `<Control>w`→`window.close`, `F10`→`win.main-menu`
- `win` actions `open`, `open-with`, `save`, `save-as`, `main-menu`; the first three of the document set start disabled
- `GtkDropTarget(File, COPY)` on the stack, `drop` → `on_file_dropped`
- error state: one `AdwToast` — *Failed to open the document. The provided password is incorrect.*

### `menu primary_menu` (inside `window.ui`)
Three sections, eight attributes: *_New Window* `app.new-window`; *_Save* `win.save` `<control>s`, *Save _As…* `win.save-as` `<control><shift>s`, *Open _With…* `win.open-with`, all three `hidden-when="action-disabled"`; *_Keyboard Shortcuts* `app.shortcuts`, *_About Paper Clip* `app.about`.

### `src/application.vala` — `Adw.Application`
App id `io.github.diegoivan.pdf_metadata_editor`, `HANDLES_OPEN`; actions `about`, `shortcuts`, `query-quit`, `new-window` with `<Ctrl>question` / `<Ctrl>q` / `<Ctrl>n`; `open()` opens one window per PDF and logs non-PDFs; `startup`/`shutdown` call `Xmp.init`/`terminate`; `query-quit` collects every dirty manager into one `SaveChangesDialog`. `AdwAboutDialog` with icon, name, copyright, developer, developers, artists, issue url, GPL-3.0, `translator_credits`, version, website and `debug_info` (which prints `Poppler <version> (Compile Time)` and `Exempi <version>`).

### `src/main.vala` — `--new-window`/`-w`, `--version`/`-v`

### `src/DocumentView.vala` + `src/gtk/document-view.ui` — the editor page
`AdwBin` → `GtkScrolledWindow` → `AdwClamp` (`.document-view-drop`) → `GtkBox(vertical,18)`; children in order `PaperClipDocumentThumbnail` (margin-top 12), `GtkLabel` (`.title-1`), `AdwPreferencesGroup` (5 `AdwEntryRow` + 2 `PaperClipDateRow`), `PaperClipKeywordList`, `AdwPreferencesGroup` *Non-Editable Properties* → `PaperClipDetailsList`. `<Control>s`/`<Control><Shift>s`; eight bindings plus the title push; empty `editor` action group; `Gtk.FileLauncher(always_ask)`; `.long-filename` above 45 chars with a space, `ellipsize=END` above 21 without.

### `src/DocumentThumbnail.vala` — page-one preview
`Adw.Bin` → `GtkImage` (`.icon-dropshadow`, `pixel_size = MAX_SIZE/2`); `MAX_SIZE = 350`; snapshot of a white `append_color` rectangle under `append_scaled_texture`, `NEAREST` upscaling else `TRILINEAR`; `compute_scaled_size` from AdwAvatar; destructor clears the image.

### `src/Services/Thumbnailer.vala` — off-thread renderer
Singleton; `create_thumbnail(page, basename)` renders a Cairo ARGB32 surface on `ThreadManager`; over `max_size² × 2.5` it writes a PNG to `$TMPDIR/thumbnails/<basename>.png` and reloads it through `Gdk::Pixbuf.from_file_at_size` at the first 0.1 step that clears the budget, under it builds a `Gdk.MemoryTexture` with an endian-chosen format; `errordomain ThumbnailError { FAILED_EXPORT, FAILED_TO_CACHE }`.

### `src/DetailsList.vala` + `src/gtk/details-list.ui`
`AdwBin` → `GtkListBox` (`.boxed-list`, valign start); 7 `AdwActionRow` (`selectable=false`, `.property`) — *Format*, *Layout*, *Duplex*, *Subtype*, *Contains JavaScript*, *Contains Attachments*, *Number of Pages* — then 2 `PaperClipStringArrayRow` — *Viewer Preferences*, *Permissions*. *Yes*/*No*; the pages row hides at zero.

### `src/StringArrayRow.vala`
`Adw.ExpanderRow` + `ContentRow : Gtk.ListBoxRow` → `GtkLabel` (`.dim-label`, halign START, margin-start 12, margin-top 18), contents joined `"• %s\n"`.

### `src/DateRow.vala` + `src/gtk/date-row.ui`
`Adw.ActionRow`; suffix `GtkButton` `entry-clear-symbolic` (`.flat`, *Remove Date*); suffix `GtkMenuButton` (`.flat`, *Show Calendar*) → `GtkPopover` → `GtkBox(vertical,6)` → `GtkCalendar` (`day-selected`) + `.linked` homogeneous *Today*/*Tomorrow*; subtitle `%x` or *No date set*.

### `src/KeywordList.vala` + `src/gtk/keyword-list.ui`
`Adw.PreferencesGroup` *Keywords*; header-suffix `GtkButton` `list-add-symbolic` (`.flat`, *Add a keyword*, `keyword-list.add-keyword`) with `visible` bound to `is-empty` inverted; `GtkListBox` (`.boxed-list`), `row-activated`; `<Control>Return`; action group `keyword-list`; empty state `AdwPreferencesRow` → `GtkCenterBox` → `GtkImage` (halign END, hexpand, margin-end 12) + `GtkLabel` *Add Keyword*; two focus rules.

### `src/KeywordRow.vala`
`Adw.EntryRow`, focusable, title *Keyword*, prefix `GtkButton` `cross-symbolic` (`.flat`, *Delete Keyword*).

### `src/DropOverlay.vala`
`Adw.Bin` → `GtkOverlay` + overlaid `GtkRevealer` (`can_target=false`, `visible=false`, CROSSFADE); `notify::current-drop` adds/removes `.overlay-drag-area`.

### `src/PasswordDialog.vala` + `src/gtk/password-dialog.ui`
`Adw.Dialog` 350×320, title *Password Dialog*, `closed` → `on_closed`; `AdwToolbarView` → `AdwHeaderBar` (`show-title=false`) → `AdwStatusPage` (`.compact`, `key-symbolic`, *This Document Is Encrypted*, description = basename) → `AdwClamp` → `GtkBox(vertical,12)` → `GtkListBox` (`.boxed-list`) → `AdwPasswordEntryRow` *Password*; `GtkButton` *Decrypt* (`.pill .suggested-action`, `dialog.success`); capture-phase `Return`/`Escape`; action group `dialog`; `errordomain PasswordDialogError { CANCELLED }`.

### `src/SaveChangesDialog.vala` + `src/gtk/save-changes-dialog.ui`
`Adw.MessageDialog` *Save Changes?*, body, default `save`, close `cancel`, responses `_Cancel` / `_Discard` (destructive) / `_Save` (suggested); `GtkScrolledWindow` → `GtkListBox` (`.boxed-list`); `DocumentRow : Adw.ActionRow` with a valign-center `GtkCheckButton` bound to `selected`, title `document.title`, subtitle basename, checked by default; `enum SaveChangesResponse`.

### `src/gtk/shortcut-window.ui`
`GtkShortcutsWindow`, modal, one `GtkShortcutsSection` (`max-height=10`), two `GtkShortcutsGroup`s, eight `GtkShortcutsShortcut`s, all ten strings `context="shortcut window"`.

### Non-widget units
`src/Document.vala` (+ `StringObject`, `XmpError`), `src/Services/DocumentManager.vala`, `src/ThreadManager.vala`, `src/Models/AsyncTask.vala`, `src/style.css` (`.long-filename`, `stack:drop(active)`, `.overlay-drag-area`), `src/pdf-metadata-editor.gresource.xml` (9 templates + 5 symbolic icons), `vapi/`.

### Non-code upstream files
`data/*.desktop.in`, `*.metainfo.xml.in`, `*.gschema.xml`, `*.service.in`, `data/nautilus-extension/paper-clip.py`, `data/screenshots/*.png` (4), `data/meson.build` (**three declared `meson test` targets**), `po/` (18 languages + LINGUAS + POTFILES + .pot), `COPYING`, `io.github.diegoivan.pdf_metadata_editor.json` (Flatpak manifest), `Paper-Clip.doap`, `README.md`.

## Port inventory

| Upstream unit | Port file | Driven |
|---|---|---|
| `src/window.ui` + `src/window.vala` | `lib/paper_clip/window.rb` | ✓ steps 0–7, 45–59, 72–84 |
| `menu primary_menu` | `lib/paper_clip/primary_menu.rb` | ✓ steps 5–7 |
| `src/application.vala` (app object) | `lib/paper_clip/application.rb` | ✓ steps 3, 78–91 |
| `src/application.vala` (About) | `lib/paper_clip/about_dialog.rb` | ✓ steps 10–11 |
| `src/main.vala` + options | `lib/paper_clip/main.rb` | ✓ step 93 |
| `src/DocumentView.vala` + `.ui` | `lib/paper_clip/document_view.rb` | ✓ steps 12–27, 40, 56–59, 98 |
| `src/DocumentThumbnail.vala` | `lib/paper_clip/document_thumbnail.rb` | ✓ step 15 (blank page only — see parity report) |
| `src/Services/Thumbnailer.vala` | `lib/paper_clip/thumbnailer.rb` | partial — memory branch only |
| `src/DetailsList.vala` + `.ui` | `lib/paper_clip/details_list.rb` | ✓ steps 17, 54–55 |
| `src/StringArrayRow.vala` (both classes) | `lib/paper_clip/string_array_row.rb` | ✓ steps 18–19 |
| `src/DateRow.vala` + `.ui` | `lib/paper_clip/date_row.rb` | ✓ steps 16, 23–27 |
| `src/KeywordList.vala` + `.ui` | `lib/paper_clip/keyword_list.rb` | ✓ steps 28–39 |
| `src/KeywordRow.vala` | `lib/paper_clip/keyword_row.rb` | ✓ steps 31–34 |
| `src/DropOverlay.vala` | `lib/paper_clip/drop_overlay.rb` | ✓ steps 45–53 |
| `src/PasswordDialog.vala` + `.ui` | `lib/paper_clip/password_dialog.rb` | ✓ steps 60–71 |
| `src/SaveChangesDialog.vala` + `.ui` | `lib/paper_clip/save_changes_dialog.rb` + `document_row.rb` | ✓ steps 72–84 |
| `src/gtk/shortcut-window.ui` | `lib/paper_clip/shortcuts_dialog.rb` | ✓ steps 8–9 |
| `src/Document.vala` | `document.rb` + `pdf_strings.rb` + `pdf_crypt.rb` + `xmp_packet.rb` + `poppler.rb` | ✓ specs + steps 12–44, 96 |
| `src/Services/DocumentManager.vala` | `lib/paper_clip/document_manager.rb` | ✓ specs + steps 41–44 |
| `src/ThreadManager.vala` | `lib/paper_clip/thread_manager.rb` | ✓ steps 94–95 |
| `src/Models/AsyncTask.vala` | folded into the dialogs' callbacks | ✓ steps 62–70 |
| `WindowState` enum | `lib/paper_clip/window_state.rb` | ✓ step 92 |
| `src/style.css` | `lib/paper_clip/style.rb` | ✓ step 2 |
| `Intl.*` in `application.vala` | `lib/paper_clip/translations.rb` | ✓ step 97 + spec |
| gresource icons (5) | `data/icons/hicolor/scalable/actions/*.svg` | ✓ step 1 |
| `data/*.desktop.in`, `*.metainfo.xml.in`, `*.gschema.xml`, `*.service.in`, `nautilus-extension/` | present under `data/` | — |
| `po/` (18 languages) | `po/` | — |
| `data/meson.build` + `src/meson.build` + `meson.build` | `flake.nix` + `Rakefile` + gemspec | — |
| **`COPYING`** | **— none —** | — |
| **`io.github.diegoivan.pdf_metadata_editor.json`** (Flatpak) | **— none —** | — |
| **`Paper-Clip.doap`** | **— none —** | — |
| `data/screenshots/*.png` (4) | — none, and none needed (the metainfo cites upstream's raw URLs) | — |

## Identification-level gaps

1. **`COPYING` has no port counterpart.** Upstream ships the GPL-3 text at the
   root. `paper-clip-rb.gemspec:18` declares `GPL-3.0-or-later` and no file in
   the tree carries the licence it names. A distributor who takes the repo
   takes a GPL work with no licence text in it.
2. **No Flatpak manifest.** Upstream's
   `io.github.diegoivan.pdf_metadata_editor.json` is how Paper Clip reaches
   users — Flathub is its distribution channel. The port builds through
   `flake.nix` and cannot be built as a Flatpak at all, so the port cannot be
   shipped the way the app it ports is shipped.
3. **No `.doap`.** `Paper-Clip.doap` is the GNOME project-metadata file. One
   file, no runtime effect, still absent.

## Correspondences, located

- `AdwBin` roots on `DocumentView` and `DetailsList` are collapsed into the
  child they wrapped (`document_view.rb:76` is the `ScrolledWindow`,
  `details_list.rb:57` is the `ListBox`). The tree is otherwise identical and
  nothing attaches to the bin.
- `GtkShortcutsWindow` → `Adwaita::ShortcutsDialog` (GTK 4.18 deprecated the
  former); upstream's two `GtkShortcutsGroup`s become two
  `Adwaita::ShortcutsSection`s, since Adwaita has no group inside a section.
  Both render — `tmp/shots/03-shortcuts.png`.
- `AdwMessageDialog` → `Adwaita::AlertDialog`, libadwaita's own 1.6
  replacement.
- The five gresource icons become five files in a `hicolor` theme directory
  the application adds to the icon search path; step 1 asserts all five plus
  the application icon are found by the theme.
- `Xmp.init` / `Xmp.terminate` have nothing to call: the port edits the XMP
  packet as XML (`lib/paper_clip/xmp_packet.rb`).
- The seven `AdwActionRow`s of `DetailsList` and the five `AdwEntryRow`s of
  `DocumentView` are built from a table in a loop
  (`details_list.rb:67`, `document_view.rb:36`), which the scan reports as
  one row each. Counted at the call sites: seven and five.

## Re-verification — round 4, `ruby` @ `1ce848a`

Four commits landed between the previous census and this one
(`68ebeda`, `b292c1c`, `8ef5c25`, `8052786`, `1ce848a`). None of them touch a
widget file: they package the gem (`68ebeda`), merge a scaffold sync
(`8ef5c25`), and fix `Document#save`/`DocumentManager#save`/`Window` to pass a
`Gio::File` through to `replace_contents` instead of a bare path
(`8052786`) — a correctness fix with no widget, CSS, signal or action
surface. `git diff 73a0b7e..1ce848a -- lib/ exe/` touches only
`document.rb`, `document_manager.rb` and `window.rb`'s saving methods.

Re-checked by hand, not just re-read:

- `ls COPYING *.doap *.json` at the repo root — still nothing for any of the
  three. The three identification-level gaps stand unchanged.
- `nix develop --command xvfb-run -a ruby test/drive_paper_clip.rb` re-run for
  this round: **278 of 278 checks passed, `DRIVE OK`**.
- `nix develop --command rspec` re-run: **134 examples, 0 failures**.

The inventory above is unchanged and current as of `1ce848a`.
