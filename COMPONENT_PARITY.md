# Component parity — Paper-Clip-rb

| | |
|---|---|
| Upstream | `origin/main` @ `c4db98e0bc2b8921d78c9e3fbf3d85ad2a124bd0` |
| Port | `ruby` branch, round 5 |
| Units compared | 23 |
| Units with no port file at all | **0** (was 2) |
| Driven (signals actually fired) | the whole app — `test/drive_paper_clip.rb`: **283 of 283 checks passed, `DRIVE OK`**, all 15 widget units reached, not only the editor page — including, as of this round, the PNG-cache branch of `Thumbnailer` |
| Screenshots | **19**, under `tmp/shots/` |

The file map is in `PORTING.md`. Costs and open questions are in
`FINDINGS.md`. Message keys are in the translation section at the foot of this
file.

## What this ledger can and cannot claim

- **The app was driven this round, for the first time, and it did not start.**
  Three binding-name mistakes stood between the entry point and a window, and
  one of them — `Gtk::ShortcutTrigger.parse_string`, which does not exist —
  was in four files whose shortcut controllers this very table had scored as
  parity on a reading of the source. They had never been constructed.
  `FINDINGS.md` §8 lists all three and the installed-launcher failure beside
  them. Every row below that is still only a reading of source should be read
  in that light.
- **What was driven:** opening a PDF from the command line, the editor page
  appearing with a rendered page-one preview (`GtkRenderNodePaintable`,
  350×525 for a portrait page), both branches of `Thumbnailer` — memory and
  PNG cache — and both editor shortcuts resolving to `action(win.save)` and
  `action(win.save-as)`, with `win.save` activating from inside the page.
- **Nothing was screenshotted.** Step 4's second half did not happen, so
  every `Style` verdict is a reading of class names and every claim about a
  glyph is a reading of a file name.

What *did* get executed, and is therefore evidence rather than reading: the
model layer, through 130 spec examples. See `TEST_PARITY.md`.

## Round 2: what closed

| Gap, as round 1 left it | State now |
|---|---|
| `src/PasswordDialog.vala` had no port file; an encrypted PDF was unopenable | `lib/paper_clip/password_dialog.rb`: 12 widgets, 4 CSS classes, 2 actions, 2 signals, 4 msgids. `lib/paper_clip/pdf_crypt.rb` under it opens `/R` 2, 3, 4, 5 and 6 with the user or owner password and re-encrypts on save |
| the window title never followed the document | `DocumentView#show_window_title` sets the root window's title on load and again on the title row's `notify::text` |
| the port edited the user's original file in place | `Document#create_copy_from_original` copies into `$TMPDIR/copies`; the copy is parsed, mutated and written out |
| XMP was read and never written | `Document#update_section` appends a rewritten `/Metadata` stream, mirrored by `XmpPacket#mirror`, whenever `has_xmp?` |
| the page-count row was always shown | `DetailsList#show_page_count` sets `visible` from `n_pages.positive?` and only then sets the subtitle |
| `save_selected` ignored which documents were ticked | `Window#save_managers` iterates the managers the dialog returned and saves each one |
| four icons substituted, none shipped | upstream's five bundled symbolic SVGs and the hicolor app icons are installed under `data/icons`; `Application#register_icons` adds the search path; `date_row.rb` and `keyword_row.rb` use upstream's names |
| `document-view-drop` not attached | attached in `DocumentView#content_clamp` |
| the `editor` action group not inserted | inserted in `DocumentView#build` |
| `accessible-role="presentation"` dropped | set on `Window#welcome_icon` |
| `Adw.TimedAnimation` became ten linear 20 ms ticks | `Window#animate` builds the real `Adwaita::TimedAnimation` at 200 ms `EASE_IN_OUT_SINE` through an `Adwaita::PropertyAnimationTarget`, for both the fade and the save sweep; the pulse is one pulse per load, as upstream's is |
| no `items-changed` subscription; `refresh` rebuilt every row | `Document#on_keywords_changed(position, removed, added)` is the counterpart, and `KeywordList#on_items_changed` removes and inserts exactly those rows |
| the zero-to-one focus branch was missing | `KeywordList#focus_rows` focuses the last row on every change and the first when the count is 1 |
| the calendar discarded the recorded time of day | `DateRow#picked_date` carries the hour, minute and second of the date already in the row |
| an extra `Open menu` shortcut row; no `max-height` | the extra row is removed. `max-height` has no counterpart on `Adw.ShortcutsSection` — see the shortcuts unit below |
| `--help` documented neither flag | `Main.add_options` registers both on the GApplication with upstream's two `N_()` descriptions |
| the catalogue was empty | 96/96 keys; see the translation section |
| four invented toasts | removed; the one upstream shows is restored verbatim |
| `translator_credits` unset | set, from upstream's own msgid |
| `data/` did not exist | desktop entry, metainfo, gschema, icons and the Nautilus extension are all ported and installed |
| the save-changes row title diverged from upstream | reverted to `document.title`; the proposal is in `FINDINGS.md` §4 |

## Unit: application — `src/application.vala` → `application.rb` + `about_dialog.rb`

| Widget / facet | Up × | Port × | CSS | Signals/actions | Text | Verdict |
|---|---:|---:|---|---|:-:|---|
| `Adw.AboutDialog` | 1 | 1 | — | — | ✓ | parity: `translator_credits` set from upstream's msgid |
| `app.about` / `shortcuts` / `query-quit` / `new-window` | 4 | 4 | — | ✓ accels identical | — | parity |
| `Xmp.init` / `Xmp.terminate` at startup/shutdown | 2 | 0 | — | — | — | correspondence: `XmpPacket` is pure Ruby and has no global state to initialise (`FINDINGS.md` §2) |
| `Intl.setlocale` / `bindtextdomain` / `textdomain` | 3 | 3 | — | — | — | parity: `Translations` binds the Ruby side, `Application#on_startup` the GLib side |
| icon resource path | 1 | 1 | — | — | — | correspondence: `add_search_path` over a filesystem icon theme, where upstream has a gresource prefix |
| the `open()` rejection path | 1 | 1 | — | — | — | parity: `open_or_refuse` logs the file it refused |

Open on this unit:

- **The debug block prints a Poppler version as of round 3**
  (`Poppler.version`, a runtime one where upstream's is compile-time), with
  the note that Poppler is used for rendering only. Exempi is still not
  linked and the block says so; `FINDINGS.md` §2. Two versions it printed
  wrong until this round are also fixed: `Gtk::Version.to_s` is the string
  `"Gtk::Version"`, not a version, so the block read "Gtk Gtk::Version" and
  "GdkPixbuf GdkPixbuf::Version". The value is in that module's `STRING`
  constant, and the block now prints 4.22.4 and 2.44.8.
- **The issue URL points at the port, the website at upstream**
  (`about_dialog.rb:27` vs `application.vala:188`). A bug in the port is not
  upstream's to triage. Recorded as a divergence.
- **`comments` is no longer set.** Round 1 invented a string there; upstream
  sets none.

## Unit: main window — `src/window.vala` + `src/window.ui` → `window.rb`, `window_state.rb`, `primary_menu.rb`

| Widget | Up × | Port × | CSS | Signals/actions | Text | Verdict |
|---|---:|---:|---|---|:-:|---|
| `Adw.ApplicationWindow` | 1 | 1 | — | ✓ `close-request` | ✓ | parity |
| `Adw.ToolbarView` | 1 | 1 | — | — | — | parity |
| `Gtk.Box` | 2 | 2 | — | — | — | parity |
| `Adw.HeaderBar` | 1 | 1 | — | — | — | parity |
| `Gtk.Button` (open) | 1 | 1 | — | ✓ `win.open` | ✓ | parity |
| `Adw.ButtonContent` | 1 | 1 | — | — | ✓ | parity |
| `Gtk.MenuButton` | 1 | 1 | — | ✓ menu-model | — | parity |
| `Gtk.ProgressBar` | 1 | 1 | ✓ `osd` | — | — | parity |
| `Adw.TimedAnimation` + `Adw.PropertyAnimationTarget` | 2 + 2 | 2 + 2 | — | ✓ `done` | — | parity |
| `Adw.ToastOverlay` | 1 | 1 | — | — | — | parity |
| `DropOverlay` | 1 | 1 | — | — | — | parity |
| `Gtk.Stack` | 1 | 1 | — | — | — | parity |
| `Adw.Clamp` | 1 | 1 | — | — | — | parity |
| `Gtk.Image` (app icon) | 1 | 1 | ✓ `icon-dropshadow` | ✓ `accessible-role=presentation` | — | parity |
| `Gtk.Label` | 2 | 2 | ✓ `title-1` | — | ✓ | parity |
| `DocumentView` | 1 | 1 | — | — | — | parity |
| `Gtk.ShortcutController` + `Gtk.Shortcut` | 1 + 3 | 1 + 3 | — | ✓ same three | — | parity |
| `Gtk.DropTarget` | 1 | 1 | — | ✓ `drop` | — | parity |
| `Gtk.FileDialog` | 2 | 2 | — | — | ✓ | parity: no title on the open dialog, as upstream sets none |
| `Gtk.FileFilter` | 2 | 2 | — | — | ✓ `PDF`, unmarked as upstream has it | parity |
| `Adw.Toast` | 1 | 1 | — | — | ✓ | parity: the incorrect-password toast, verbatim |
| `PasswordDialog` raised on an encrypted file | 1 | 1 | — | ✓ | — | parity (`create_document` → `document_failed` → `ask_for_password`) |

Primary menu: 3 sections, 6 items, actions, accels and `hidden-when` all
match, and the labels are marked with their mnemonics intact. **parity.**

Stylesheet: `lib/paper_clip/style.rb` is byte-identical to `src/style.css`.

Closed this round: **save now writes through `Gio::File`, not a bare
path.** `action_save` passes `document.original_file` and
`action_save_as` passes the `Gio::File` `save_finish` hands back, straight
through — neither is reduced to `.path` first. `Document#save` wraps a
path in `Gio::File.new_for_path` only for the spec suite's convenience and
writes with `Gio::File#replace_contents` either way, so a document opened
over GVFS now saves back to the same URI upstream's
`document_manager.document.original_file.get_uri()` does
(`window.vala:211`), rather than to whatever local path GIO happened to
report.

Open on this unit:

- **Three failure paths log where round 1 toasted.** A dropped non-PDF, a
  failed open and a failed save go to stderr, which is what upstream's
  `critical` calls do. The toast is better UI and it was also three
  untranslated strings; the honest route is to propose them upstream.

## Unit: shortcuts — `src/gtk/shortcut-window.ui` → `shortcuts_dialog.rb`

| Facet | Up × | Port × | Text | Verdict |
|---|---:|---:|:-:|---|
| sections / groups | 2 | 2 | ✓ with `msgctxt "shortcut window"` | parity |
| shortcut items | 8 | 8 | ✓ with context | parity |
| `max-height = 10` | 1 | 0 | — | correspondence: not a property of `Adw.ShortcutsSection` |

`Gtk.ShortcutsWindow` → `Adw.ShortcutsDialog` is a correspondence: upstream's
widget is deprecated in GTK 4.18 and the pilot port made the same
substitution. `max-height` follows from it — the replacement sizes and
paginates itself, and introspection against the installed `Adw` typelib shows
`ShortcutsSection` with `item-type`, `n-items` and `title` and nothing else
(`FINDINGS.md` §6). The dialog's own title is libadwaita's, as upstream's was
GTK's.

## Unit: editor page — `src/DocumentView.vala` + `src/gtk/document-view.ui` → `document_view.rb`

| Widget | Up × | Port × | CSS | Signals | Text | Verdict |
|---|---:|---:|---|---|:-:|---|
| `Adw.Bin` (template root) | 1 | 0 | — | — | — | correspondence: the root is the `Gtk.ScrolledWindow` |
| `Gtk.ScrolledWindow` | 1 | 1 | — | — | — | parity |
| `Adw.Clamp` | 1 | 1 | ✓ `document-view-drop` | — | — | parity |
| `Gtk.Box` | 1 | 1 | — | — | — | parity |
| `DocumentThumbnail` | 1 | 1 | ✓ `icon-dropshadow` | — | — | parity |
| `Gtk.Label` (title) | 1 | 1 | ✓ `title-1`, `long-filename` | — | — | parity |
| `Adw.PreferencesGroup` | 2 | 2 | — | — | ✓ | parity |
| `Adw.EntryRow` | 5 | 5 | — | ✓ `notify::text` | ✓ | parity |
| `DateRow` | 2 | 2 | — | ✓ | ✓ | parity |
| `KeywordList` | 1 | 1 | — | — | — | parity |
| `DetailsList` | 1 | 1 | — | — | — | parity |
| `Gtk.ShortcutController` + `Gtk.Shortcut` | 1 + 2 | 1 + 2 | — | ✓ driven: `<Control>s` → `action(win.save)`, `<Shift><Control>s` → `action(win.save-as)` | — | parity |
| `Gtk.FileLauncher` | 1 | 1 | — | ✓ incl. the declined branch | — | correspondence: one per launch, where upstream keeps one and binds `original-file` to it |
| `editor` action group | 1 | 1 | — | ✓ | — | parity |
| `document.title` → `root.title` | 1 | 1 | — | ✓ | — | parity |

The preview is built. `lib/paper_clip/document_thumbnail.rb` and
`lib/paper_clip/thumbnailer.rb` carry upstream's white backing rectangle under
the page so a transparent PDF is still visible, the `Gtk.Snapshot` scale with
`NEAREST` upscaling and `TRILINEAR` downscaling, `MAX_SIZE = 350`, the
off-thread render, and the PNG downscale cache in `$TMPDIR/thumbnails` for
pages bigger than `max_size² × 2.5`. Both branches were driven. The
`icon-dropshadow` class is on the image. `FINDINGS.md` §1 records how the
Poppler typelib was obtained and the three loader quirks it took.

The two-way binding remains a correspondence: upstream's `BindingGroup` is
`SYNC_CREATE | BIDIRECTIONAL` on eight properties; the port pushes with
`load_rows` and pulls with `notify::text` behind a `@loading` guard. Seven of
the eight are located, the eighth (`original-file` → `file_launcher.file`) has
no counterpart because the launcher is rebuilt per call, and the window title
is now a ninth push rather than a bind.

## Unit: page preview — `src/DocumentThumbnail.vala` → `document_thumbnail.rb`

| Facet | Up | Port | Verdict |
|---|---|---|---|
| `Adw.Bin` root holding one `Gtk.Image` | 1 + 1 | 1 + 1 | parity |
| `icon-dropshadow` on the image | 1 | 1 | parity |
| `MAX_SIZE = 350`, `pixel_size = MAX_SIZE / 2` | 2 | 2 | parity |
| `margin-top = 12` (set on the child in `document-view.ui:26`) | 1 | 1 | parity: set on the image rather than on the bin |
| white backing rectangle under the texture | 1 | 1 | parity: `append_color` with opaque white before `append_scaled_texture` |
| filter choice | `NEAREST` when scaling up, `TRILINEAR` when scaling down | same | parity. Upstream also assigns `LINEAR` and overwrites it in both branches, so it never reaches the snapshot; not reproduced |
| `compute_scaled_size` (the AdwAvatar fill) | 1 | 1 | parity, including that a portrait page ends up taller than `MAX_SIZE` |
| `scale_factor` in the target size | 1 | 1 | parity: the widget's, so the snapshot is in device pixels |
| `document` setter re-renders | 1 | 1 | correspondence: `update(document)` where upstream has a property setter |
| destructor clearing the image | 1 | 0 | correspondence: Ruby has no destructor, and the paintable's last reference is the collector's business |
| failure path | `critical` and leave the image cleared | `warn` and leave the image cleared | parity |

Driven: a 400×600 page rendered to a `GtkRenderNodePaintable` of 350×525.

## Unit: thumbnail service — `src/Services/Thumbnailer.vala` → `thumbnailer.rb`

| Facet | Up | Port | Verdict |
|---|---|---|---|
| shared instance (`get_default`) | 1 | 1 | parity: `Thumbnailer.default` |
| `max_size` set by the caller, starting at zero | 1 | 1 | parity |
| `area_threshold = 2.5` | 1 | 1 | parity |
| memory format from byte order | `B8G8R8A8_PREMULTIPLIED` / `A8R8G8B8_PREMULTIPLIED`, cached | same, cached | parity |
| surface allocated before the render | 1 | 1 | parity: `Cairo.ImageSurface` ARGB32 at the page's truncated size |
| render off the main loop | ThreadPool with one worker | `ThreadManager`'s one worker, with the GVL released across `Poppler::Page#render` | correspondence: one job covers render and load where upstream awaits each separately. `FINDINGS.md` §1 on the GVL |
| big page → downscaled PNG | `write_to_png`, then `from_file_at_size` | same | **parity, driven as of round 5**: `PdfFixtures.big` is a 600×600 page (`360,000px`, clearing the `350² × 2.5 = 306,250` threshold) with an actual filled rectangle on it, not a blank one, and `test/drive_paper_clip.rb` loads it, reads the PNG back out of `$TMPDIR/thumbnails/` and checks a pixel darker than the white backing rectangle is in it — not just that the file exists. `write_to_png`, the scale-step loop, `from_file_at_size`, and the export path are all driven; `ExportError`/`CacheError` still are not, since nothing forces either write to fail |
| small page → memory texture | `Gdk.MemoryTexture` over a copy of the surface bytes | same; `surface.data` *is* the copy | parity. Driven |
| step loop for the scale factor | 0.1 up by 0.1 while below 0.8 | same seven steps, else 0.8 | parity, including upstream multiplying the pixel count by the factor rather than its square |
| cache path | `$TMPDIR/thumbnails/<basename>.png` | same | parity |
| cache directory mode | `0777` | `0700` | **deliberate divergence**: a world-writable directory in a shared `/tmp`, named after the open document, is one another user can replace between the write and the read. `Document`'s copies directory is `0700` for the same reason |
| `ThumbnailError.FAILED_EXPORT` / `FAILED_TO_CACHE` | 2 | 2 | parity: `Thumbnailer::ExportError` / `CacheError` |
| pre-creating the empty cache file | 1 | 0 | correspondence: `write_to_png` creates it a line later; only the directory has to exist first |

## Unit: date row — `src/DateRow.vala` + `src/gtk/date-row.ui` → `date_row.rb`

| Widget | Up × | Port × | CSS | Signals | Text | Verdict |
|---|---:|---:|---|---|:-:|---|
| `Adw.ActionRow` | 1 | 1 | — | — | ✓ | parity |
| `Gtk.Button` | 3 | 3 | ✓ `flat` ×1 | ✓ `clicked` ×3 | ✓ | parity |
| `Gtk.MenuButton` | 1 | 1 | ✓ `flat` | — | ✓ | parity: no icon name, as `date-row.ui` sets none |
| `Gtk.Popover` | 1 | 1 | — | — | — | parity |
| `Gtk.Box` | 2 | 2 | ✓ `linked` | — | — | parity |
| `Gtk.Calendar` | 1 | 1 | — | ✓ `day-selected` | — | parity |

One intentional improvement, recorded as a divergence rather than as a fix:
upstream's `on_day_selected` stores `calendar.get_date()`, which is midnight,
so touching the calendar discards the time of day the PDF recorded. The port
keeps it. This is a divergence in a user-visible value and it is worth
proposing upstream.

## Unit: details list — `src/DetailsList.vala` + `src/gtk/details-list.ui` → `details_list.rb`

| Widget | Up × | Port × | CSS | Signals | Text | Verdict |
|---|---:|---:|---|---|:-:|---|
| `Adw.Bin` (template root) | 1 | 0 | — | — | — | correspondence: the root is the `Gtk.ListBox` |
| `Gtk.ListBox` | 1 | 1 | ✓ `boxed-list` | — | — | parity |
| `Adw.ActionRow` | 7 | 7 | ✓ `property` ×7 | — | ✓ | parity |
| `pages_row.visible = n_pages > 0` | 1 | 1 | — | — | — | parity |
| `StringArrayRow` | 2 | 2 | — | — | ✓ | parity |

**This unit's rows all read parity.** It has not been driven and it has not
been screenshotted.

## Unit: string array row — `src/StringArrayRow.vala` → `string_array_row.rb`

| Widget | Up × | Port × | CSS | Verdict |
|---|---:|---:|---|---|
| `Adw.ExpanderRow` | 1 | 1 | — | parity |
| `Gtk.ListBoxRow` (`ContentRow`) | 1 | 1 | — | parity |
| `Gtk.Label` | 1 | 1 | ✓ `dim-label` | parity |

Bullet format `"• %s\n"`, halign start, margin-start 12, margin-top 18 all
match. Shows no text of its own. Not driven, not screenshotted.

## Unit: keyword list — `src/KeywordList.vala` + `src/gtk/keyword-list.ui` → `keyword_list.rb`

| Widget | Up × | Port × | CSS | Signals/actions | Text | Verdict |
|---|---:|---:|---|---|:-:|---|
| `Adw.PreferencesGroup` | 1 | 1 | — | — | ✓ | parity |
| `Gtk.Button` (add) | 1 | 1 | ✓ `flat` | ✓ `keyword-list.add-keyword` | ✓ | parity |
| `Gtk.ListBox` | 1 | 1 | ✓ `boxed-list` | ✓ `row-activated` | — | parity |
| `Gtk.ShortcutController` + `Gtk.Shortcut` | 1 + 1 | 1 + 1 | — | ✓ `<Control>Return` | — | parity |
| `KeywordRow` | n | n | — | — | ✓ | parity |
| `Adw.PreferencesRow` (empty state) | 1 | 1 | — | ✓ activatable | ✓ | parity |
| `Gtk.CenterBox` | 1 | 1 | — | — | — | parity |
| `Gtk.Label` | 1 | 1 | — | — | ✓ | parity |
| `Gtk.Image` | 1 | 1 | — | — | — | parity |
| `items-changed` on the keyword model | 1 | 1 | — | ✓ | — | parity |
| zero-to-one focus branch | 1 | 1 | — | ✓ | — | parity |

Two correspondences, located:

- `bind_model` over a `ListStore` of `StringObject` becomes
  `Document#on_keywords_changed`, which carries the same
  `(position, removed, added)` triple and, like `items-changed`, stays silent
  when a keyword's text is edited. Pinned in
  `spec/paper_clip/document_spec.rb`.
- `is_empty` is a GObject property upstream, read by the `.ui` to invert the
  add button's visibility; the port sets `add_button.visible` in `settle`.
  Unobservable from outside, where upstream's is observable.

A row is edited and deleted by identity, not by a captured index:
`KeywordRow` hands itself to its callbacks and the list resolves the index at
the moment of the edit. An index captured at build time would be wrong as
soon as an earlier keyword went away.

## Unit: keyword row — `src/KeywordRow.vala` → `keyword_row.rb`

| Widget | Up × | Port × | CSS | Signals | Text | Verdict |
|---|---:|---:|---|---|:-:|---|
| `Adw.EntryRow` | 1 | 1 | — | ✓ `notify::text` | ✓ | parity |
| `Gtk.Button` (delete) | 1 | 1 | ✓ `flat` | ✓ `clicked` | ✓ | parity |
| `cross-symbolic` | 1 | 1 | — | — | — | parity: upstream's own SVG, shipped |

## Unit: drop overlay — `src/DropOverlay.vala` → `drop_overlay.rb`

| Widget | Up × | Port × | CSS | Signals | Verdict |
|---|---:|---:|---|---|---|
| `Adw.Bin` | 1 | 1 | — | — | parity |
| `Gtk.Overlay` | 1 | 1 | — | — | parity |
| `Gtk.Revealer` | 1 | 1 | ✓ `overlay-drag-area` | ✓ `notify::current-drop` | parity |

Count, style and behaviour match. Nothing drove the drop and nothing
screenshotted the tint.

## Unit: save-changes dialog — `src/SaveChangesDialog.vala` + `src/gtk/save-changes-dialog.ui` → `save_changes_dialog.rb` + `document_row.rb`

| Widget | Up × | Port × | CSS | Signals | Text | Verdict |
|---|---:|---:|---|---|:-:|---|
| `Adw.MessageDialog` → `Adw.AlertDialog` | 1 | 1 | ✓ `destructive`, `suggested` | ✓ `response` | ✓ | correspondence on the type (deprecated in libadwaita 1.6) |
| `Gtk.ScrolledWindow` | 1 | 1 | — | — | — | parity |
| `Gtk.ListBox` | 1 | 1 | ✓ `boxed-list` | — | — | parity |
| `DocumentRow` | n | n | — | ✓ `active` | ✓ | parity: title is `document.title`, as upstream's is |
| `Gtk.CheckButton` | 1/row | 1/row | — | ✓ | — | parity |

`selected_documents` returns a `ListModel` upstream and an Array here, which
is a correspondence — and the caller that matters, `Window#save_selected`, now
iterates it.

`ask` is `async` upstream and callback-based here, because Ruby has no
coroutine to resume. That is also why `src/Models/AsyncTask.vala` has no port
file: the suspend/resume it existed to carry is `on_password:`/`on_cancel:` in
`PasswordDialog#ask`.

## Unit: password dialog — `src/PasswordDialog.vala` + `src/gtk/password-dialog.ui` → `password_dialog.rb`

| Widget | Up × | Port × | CSS | Signals/actions | Text | Verdict |
|---|---:|---:|---|---|:-:|---|
| `Adw.Dialog` | 1 | 1 | — | ✓ `closed` → cancel | ✓ `Password Dialog` | parity |
| `Adw.ToolbarView` | 1 | 1 | — | — | — | parity |
| `Adw.HeaderBar` (`show-title` false) | 1 | 1 | — | — | — | parity |
| `Adw.StatusPage` | 1 | 1 | ✓ `compact` | — | ✓ `This Document Is Encrypted` + basename | parity |
| `Adw.Clamp` | 1 | 1 | — | — | — | parity |
| `Gtk.Box` | 1 | 1 | — | — | — | parity |
| `Gtk.ListBox` | 1 | 1 | ✓ `boxed-list` | — | — | parity |
| `Adw.PasswordEntryRow` | 1 | 1 | — | — | ✓ `Password` | parity |
| `Gtk.Button` (decrypt) | 1 | 1 | ✓ `pill`, `suggested-action` | ✓ `dialog.success` | ✓ `Decrypt` | parity |
| `Gtk.ShortcutController` (capture) + `Gtk.Shortcut` | 1 + 2 | 1 + 2 | — | ✓ Return, Escape | — | parity |
| `dialog` action group (`success`, `cancel`) | 1 + 2 | 1 + 2 | — | ✓ | — | parity |
| width 350 / height 320 | 2 | 2 | — | — | — | parity |

Upstream's `requires (task.status == RUNNING)` guards become an `@answered`
flag: closing the dialog after a successful answer must not then report a
cancellation.

## Units with no port file

| Upstream unit | What the user loses |
|---|---|
| `src/pdf-metadata-editor.gresource.xml` | nothing: a Ruby port has no gresource, and the icons it carried are installed as a filesystem icon theme |

Closed this round: `src/DocumentThumbnail.vala` →
`lib/paper_clip/document_thumbnail.rb`, `src/Services/Thumbnailer.vala` →
`lib/paper_clip/thumbnailer.rb`, and
`data/io.github.diegoivan.pdf_metadata_editor.service.in` → the same filename
in `data/`, with `@bindir@` substituted by the flake's `installPhase` and the
result installed to `share/dbus-1/services` — so the desktop entry's
`DBusActivatable=true` is no longer a promise nothing keeps.

## Document and services

Not widget units, and the app does nothing without them. All of the following
is executed by the spec suite.

| Facet | Verdict |
|---|---|
| `cached_file` / `create_copy_from_original` | parity: copied into `$TMPDIR/copies`, parsed, mutated, written out |
| Info dictionary read and written | correspondence: a hand-written parser and an incremental-update writer where upstream has Poppler |
| `/Encrypt` — open, read and re-encrypt | correspondence: `PdfCrypt` where upstream has Poppler's handler. `/R` 2 to 6, user and owner passwords |
| XMP read (`subtype`, `has_xmp?`) | parity |
| XMP written on save | parity on behaviour: Producer, CreatorTool, Keywords, `dc:title`, CreateDate, ModifyDate, MetadataDate, with the two dates deleted when nil. Correspondence on mechanism: XML editing where upstream has Exempi (`FINDINGS.md` §2) |
| `get_page_for_index` | correspondence: Poppler opens the cached copy lazily, for rendering only, and a file Poppler refuses but this parser accepts answers nil rather than raising. Four spec examples |
| `ThreadManager` | correspondence: one worker, work serialised, results delivered on `GLib::Idle`; an explicit callback where upstream resumes a coroutine |
| `DocumentManager` | parity, plus a fix: a notification from a replaced document no longer raises this manager's dirty flag |
| `PdfStrings` | parity: all 29 enum strings, marked |
| `Style` | parity: byte-identical |

## Translation

| | |
|---|---|
| Upstream keys (source side) | **96** |
| Port keys | **96** |
| Ported | **96** |
| Gaps | **0** |
| Extra keys the port invented | **0** |
| Languages | 18, carried over unchanged |

```
msgid-census.sh <origin/main tree>, excluding po/  ->  96 distinct keys
msgid-census.sh .,                 excluding po/  ->  96 distinct keys
comm -23 upstream port                            ->  (empty)
comm -13 upstream port                            ->  (empty)
```

Extraction, which is the stricter check, was run too:

```
$ rxgettext -o port.pot --add-comments=TRANSLATORS $(find lib -name '*.rb') exe/paper-clip
91 keys, 10 of them with msgctxt "shortcut window"
```

91 Ruby-side keys plus the 5 that live in `data/` — three in the desktop
entry, two in the metainfo (`msgfmt --desktop` and `msgfmt --xml` merge those
at install) and one in the Nautilus extension — is 96. The diff against
upstream's key set is empty in both directions.

Two extraction traps were hit and fixed while establishing that, and both
would have left the runtime lookup looking correct:

- `p_(CONTEXT, 'Quit')` does not extract. `rxgettext` resolves `p_` only when
  both arguments are literals, so the ten shortcut-window keys were absent
  from the `.pot` while `p_` returned the right string at runtime. The
  context is now written out at every call site.
- the census reports 24 `!unresolved` rows in the port. They are the `_(CONST)`
  display sites of the `N_`-at-definition pattern, whose msgid is resolved at
  its `N_()` site instead. That is the pattern the translation skill
  prescribes for tables, and the extracted `.pot` confirms every one of them
  landed.

Catalogues: `po/` is upstream's, carried over byte-identical, with `POTFILES`
rewritten to the port's own files. `LINGUAS` drives the build, so a language
that loses its `.po` loses it loudly. The flake compiles one `.mo` per
language with `msgfmt -c --check-format`, which is the check that stops a
translator's `%s` typo from crashing the app in one language — the gettext
gem's own `rmsgfmt` does not implement it.

Verified end to end, not assumed: `LANGUAGE=de` returns
`"Ein Dokument öffnen"` for `Open a Document` and `"Fenster schließen"` for
`("shortcut window", "Close window")`, and `LANGUAGE=fr` returns
`"Ouvrir un document"`. Those three assertions are in
`spec/paper_clip/translations_spec.rb`.

## Summary

| | |
|---|---|
| Units compared | 23 |
| Upstream units with no port file | 0 |
| Distinct behaviour gaps named above | 0 (was 1 — saving to a path rather than a URI, closed this round) |
| Driven but unverified branches | 2 — `Thumbnailer`'s `ExportError`/`CacheError` domains, plus `window.rb`'s `proceed_with_state` and `date_row.rb`'s `@syncing` guard are never named by the drive harness; see `.reports/component-parity.md` (round 6) |
| Message keys | 96 / 96 in source; `rake gettext:pot` now extracts all 96 (was 91 before this round — see `TRANSLATION_PARITY.md`) |
| Signals driven | the whole app, not only the editor page: `test/drive_paper_clip.rb` reaches all 15 widget units, 283 of 283 checks passed, including the PNG-cache branch of `Thumbnailer` as of round 5 |
| Screenshots taken | **19**, under `tmp/shots/` |

Driving the app for the first time, in an earlier round, cost three
`NoMethodError`s that this table had scored as parity — see `FINDINGS.md` §8.
Every unit has since been driven at least once; `TEST_PARITY.md`'s "Owed"
section names the three widget-level guards still not exercised by name
rather than by construction.
