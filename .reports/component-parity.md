# Component parity — Paper Clip

| | |
|---|---|
| Upstream | `origin/main` @ `c4db98e0bc2b8921d78c9e3fbf3d85ad2a124bd0` |
| Port | `ruby` @ `6d05c88af0f4ad6db5fbd16c88b1d4d9a93d632c` |
| Units with parity | **0 / 17** |
| Units with no port file at all | 6 |
| Driven (signals actually fired) | **0** — no driver run exists |
| Screenshots | **none** |

Inventories: `.reports/component-inventory.md` (upstream) and
`.reports/component-identification.md` (port). Scopes and file mapping are in
the latter.

Two things this ledger cannot claim and does not:

- **Nothing was driven.** Step 5 of the skill was not satisfied. Every
  behaviour row below is a static reading of the source; a handler connected
  to an empty method would pass it. `.claude/skills/ruby-gtk-testing` has the
  driver and nothing in this repo has ever run it.
- **Nothing was screenshotted.** Step 4's second half — run the port and look
  — did not happen, so every `Style` verdict is a reading of class names.

## Unit: application — `src/application.vala` → `application.rb` + `about_dialog.rb`

| Widget / facet | Up × | Port × | CSS | Signals/actions | Text | Verdict |
|---|---:|---:|---|---|:-:|---|
| `Adw.AboutDialog` | 1 | 1 | — | — | ✗ | **gap**: `translator_credits` not set at all |
| `app.about` / `shortcuts` / `query-quit` / `new-window` | 4 | 4 | — | ✓ accels identical | — | parity (installed in a loop, `application.rb:34`) |
| `Xmp.init` / `Xmp.terminate` at startup/shutdown | 2 | 0 | — | ✗ | — | **gap**: no XMP layer exists |

Gaps:

- **`translator_credits` is never set.** Upstream `src/application.vala:183`
  passes `_("translator_credits")`; the port's `about_dialog.rb:33-44` sets
  nine properties and not that one. Eighteen languages have a credits line
  and no user of this port will ever see their own name.
- **The debug block lost three libraries and gained two.** Upstream prints
  Gtk, Libadwaita (`Adw.VERSION_S`), Poppler, Exempi and GdkPixbuf
  (`application.vala:196-206`); the port prints Gtk, Libadwaita and Ruby
  (`about_dialog.rb:48-58`). A bug report filed against this port cannot say
  which GdkPixbuf rendered the thumbnail, because there is no thumbnail.
- **The issue URL points at the port, the website at upstream.** Deliberate or
  not, it is a divergence in a user-visible dialog and it is recorded here:
  `about_dialog.rb:28` vs `application.vala:180`.
- **`comments` is a new user-visible string** the port invented
  (`about_dialog.rb:29`), untranslated, with no upstream counterpart.
- **The `open()` rejection path is silent.** Upstream `critical()`s the file
  it refused (`application.vala:105`); the port's `on_open` filters with
  `select` (`application.rb:100`) and a user who double-clicks a `.txt`
  associated by accident gets nothing — no window, no message, no log line.

## Unit: main window — `src/window.vala` + `src/window.ui` → `window.rb`, `window_state.rb`, `primary_menu.rb`

| Widget | Up × | Port × | CSS | Signals/actions | Text | Verdict |
|---|---:|---:|---|---|:-:|---|
| `Adw.ApplicationWindow` | 1 | 1 | — | ✓ `close-request` | ✗ | **gap**: title never follows the document |
| `Adw.ToolbarView` | 1 | 1 | — | — | — | parity |
| `Gtk.Box` | 2 | 2 | — | — | — | parity |
| `Adw.HeaderBar` | 1 | 1 | — | — | — | parity |
| `Gtk.Button` (open) | 1 | 1 | — | ✓ `win.open` | ✗ unmarked | **gap**: text axis |
| `Adw.ButtonContent` | 1 | 1 | — | — | ✗ unmarked | **gap**: text axis |
| `Gtk.MenuButton` | 1 | 1 | — | ✓ menu-model | — | parity |
| `Gtk.ProgressBar` | 1 | 1 | ✓ `osd` | — | — | **gap**: animation, below |
| `Adw.ToastOverlay` | 1 | 1 | — | — | — | parity |
| `DropOverlay` | 1 | 1 | — | — | — | parity |
| `Gtk.Stack` | 1 | 1 | — | — | — | parity |
| `Adw.Clamp` | 1 | 1 | — | — | — | parity |
| `Gtk.Image` (app icon) | 1 | 1 | ✓ `icon-dropshadow` | — | — | **gap**: `accessible-role="presentation"` dropped (`window.ui:79` vs `window.rb:196`) — a screen reader now announces the decorative icon |
| `Gtk.Label` | 2 | 2 | ✓ `title-1` | — | ✗ unmarked | **gap**: text axis |
| `DocumentView` | 1 | 1 | — | — | — | parity |
| `Gtk.ShortcutController` | 1 | 1 | — | ✓ | — | parity |
| `Gtk.Shortcut` | 3 | 3 | — | ✓ same three | — | parity |
| `Gtk.DropTarget` | 1 | 1 | — | ✓ `drop` | — | parity |
| `Gtk.FileDialog` | 2 | 2 | — | — | ✗ | **gap**: the port sets `title = 'Open a Document'` (`window.rb:291`) where upstream sets none (`window.vala:131`) — a reused msgid in a place upstream never put it |
| `Gtk.FileFilter` | 2 | 2 | — | — | ✓ `PDF` | parity |
| `Adw.Toast` | 1 | 4 | — | — | ✗ | **gap**: see below |

Gaps:

- **The window title never becomes the document title.** Upstream
  `DocumentView.document` setter runs
  `document.bind_property("title", root, "title", SYNC_CREATE)`
  (`src/DocumentView.vala:66`), so the titlebar and the window list show the
  PDF's title and track it as you type. The port sets
  `win.title = TITLE` once (`window.rb:140`) and never touches it again. Every
  open window in the port says "Paper Clip", so a user with four PDFs open
  cannot tell them apart from the taskbar.
- **The one toast upstream shows was reworded, and three were invented.**
  Upstream has exactly one: `_("Failed to open the document. The provided
  password is incorrect.")` (`window.vala:165`), shown when the password the
  PasswordDialog collected was wrong. The port replaced it with
  `'Failed to open the document. It is encrypted.'` (`window.rb:53`) — a
  different sentence that no catalogue has — and added
  `'Failed to open the document.'`, `'That file is not a PDF.'`
  (`window.rb:54-55`) and `'Failed to save the document.'`
  (`window.rb:417`). Four user-visible strings in the error path, none of
  them translated, one of them standing in for a dialog that does not exist.
  This row is open in `TRANSLATION_PARITY` terms in
  `.reports/translation-parity.md` too.
- **The encrypted path is a dead end.** Upstream `create_document`
  (`window.vala:174-190`) catches `Poppler.Error.ENCRYPTED`, raises a
  `PasswordDialog`, and loads the document with the password the user typed.
  The port's `document_failed` (`window.rb:387`) shows a toast and stops. An
  encrypted PDF is unopenable in this port. That is one of the four states
  `component-identification` counts as an error state and it has no
  counterpart at all.
- **`Adw.TimedAnimation` became a timeout loop.** Upstream animates
  `fraction` 0→1 and `opacity` 1→0 over 200 ms with `EASE_IN_OUT_SINE` through
  `Adw.PropertyAnimationTarget` (`window.vala:230-243`, `window.vala:257-263`).
  The port steps `fraction` and `opacity` in ten linear 20 ms ticks
  (`window.rb:471-511`). Different easing, different duration, and the pulse
  is a repeating 100 ms timeout where upstream pulses once per load. The
  `Adw.TimedAnimation` row is a `type` row, so it is compared as plumbing —
  but the rendered motion differs and that is the part a user sees.
- **`save_failed` and the save path diverge on what gets saved.** Upstream
  saves to `document_manager.document.original_file.get_uri()`
  (`window.vala:217`); the port saves to `document.path` (`window.rb:271`).
  Upstream's `Document.save` writes the *cached copy* out to that URI; the
  port rewrites the original in place, because it never made a copy. See the
  Document unit.
- **The dropped-file refusal differs.** Upstream `critical`s and returns false
  with no UI (`window.vala:92`); the port shows a toast. The toast is better
  and it is still a divergence, recorded, with an untranslated string.
- **`save_selected` ignores which managers were ticked.** `window.rb:437`
  saves `@document_manager.document.path` whenever `managers` is non-empty,
  so the checkbox in the single-window dialog decides only *whether* to save,
  never *what*. Upstream's dialog returns a `ListModel` of the selected
  managers and the app saves exactly those (`application.vala:168-174`).

Primary menu: 3 sections, 6 items, actions, accels and `hidden-when` all match
(`primary_menu.rb:18-32` vs `window.ui` `<menu id="primary_menu">`). Labels are
byte-identical and **unmarked**. `parity` on count, style, behaviour; **gap**
on text.

Stylesheet: `lib/paper_clip/style.rb:19-33` is byte-identical to
`src/style.css` — all three rules, same values. The one CSS gap in the app is
an *attachment* gap, below.

Messages: 10 upstream msgids in `window.ui` + 1 in `window.vala`; 11 present
in the port as bare literals, 1 reworded, 4 invented. **gap**.

## Unit: shortcuts — `src/gtk/shortcut-window.ui` → `shortcuts_dialog.rb`

| Facet | Up × | Port × | Text | Verdict |
|---|---:|---:|:-:|---|
| sections / groups | 2 | 2 | ✗ | **gap**: `msgctxt "shortcut window"` dropped |
| shortcut items | 8 | 9 | ✗ | **gap**: one extra, all unmarked |
| `max-height = 10` | 1 | 0 | — | **gap** |

Gaps:

- **Every one of these ten msgids carries `msgctxt "shortcut window"`
  upstream** (`shortcut-window.ui:9-77`) and the port has no context on any of
  them (`shortcuts_dialog.rb:16-29`). Even if the port were marked tomorrow,
  `("shortcut window", "Open")` and `(nil, "Open")` are different keys and
  the eighteen catalogues are keyed on the first.
- **An extra item: `['Open menu', 'F10']`** (`shortcuts_dialog.rb:21`).
  Upstream's General group has four entries and does not list F10 at all. The
  shortcut itself is real and bound, so the honest fix is to propose the row
  upstream; until then it is an unexplained extra and a tenth untranslated
  string.
- **The dialog title `'Keyboard Shortcuts'`** (`shortcuts_dialog.rb:33`) is a
  new string in a new place; upstream's `GtkShortcutsWindow` titles itself.
- `Gtk.ShortcutsWindow` → `Adw.ShortcutsDialog` is a **correspondence**, not a
  gap: upstream's widget is deprecated in GTK 4.18 and the pilot port
  (`gnome-contacts-rb/lib/shortcuts_dialog.rb`) made the same substitution.
  Recorded, with the reason.

## Unit: editor page — `src/DocumentView.vala` + `src/gtk/document-view.ui` → `document_view.rb`

| Widget | Up × | Port × | CSS | Signals | Text | Verdict |
|---|---:|---:|---|---|:-:|---|
| `Adw.Bin` (template root) | 1 | 0 | — | — | — | correspondence: the port's root is the `Gtk.ScrolledWindow` (`document_view.rb:107`) |
| `Gtk.ScrolledWindow` | 1 | 1 | — | — | — | parity |
| `Adw.Clamp` | 1 | 1 | ✗ `document-view-drop` | — | — | **gap** |
| `Gtk.Box` | 1 | 1 | — | — | — | parity |
| `DocumentThumbnail` | 1 | **0** | ✗ `icon-dropshadow` | — | — | **gap** |
| `Gtk.Label` (title) | 1 | 1 | ✓ `title-1`, `long-filename` | — | — | parity on style |
| `Adw.PreferencesGroup` | 2 | 2 | — | — | ✗ unmarked | **gap**: text |
| `Adw.EntryRow` | 5 | 5 | — | ✓ `notify::text` | ✗ unmarked | **gap**: text |
| `DateRow` | 2 | 2 | — | ✓ | ✗ unmarked | **gap**: text |
| `KeywordList` | 1 | 1 | — | — | — | parity |
| `DetailsList` | 1 | 1 | — | — | — | parity |
| `Gtk.ShortcutController` + `Gtk.Shortcut` | 1 + 2 | 1 + 2 | — | ✓ | — | parity |
| `Gtk.FileLauncher` | 1 | 1 | — | — | — | correspondence: upstream keeps one and binds `original-file` to it (`DocumentView.vala:100`); the port builds one per launch (`document_view.rb:208`) |
| `editor` action group | 1 | **0** | — | ✗ | — | **gap** |

Gaps:

- **The page-one preview is not built.** Upstream shows a rendered thumbnail
  of page 1 above the filename (`document-view.ui:25`,
  `src/DocumentThumbnail.vala`, `src/Services/Thumbnailer.vala`): a white
  background rectangle under the page so transparent PDFs are visible, a
  `Gtk.Snapshot` scale with `NEAREST` upscaling and `TRILINEAR` downscaling,
  `MAX_SIZE = 350` and a PNG downscale cache in `$TMPDIR/thumbnails` for pages
  bigger than `max_size² × 2.5`. The port shows nothing there, so a user
  cannot confirm they opened the right PDF before editing it, and the
  `icon-dropshadow` class on that image is attached nowhere.
- **The `document-view-drop` class is not attached.** `document-view.ui:14`
  puts it on `content_clamp`; `document_view.rb:117` builds a bare
  `Adwaita::Clamp`. Upstream defines no rule for it in `src/style.css`, so
  upstream has a class applied and never defined — a bug worth reporting
  upstream — and the port has the opposite bug: the attachment removed
  without the question being answered.
- **The `editor` action group is not inserted.** `DocumentView.vala:79`
  inserts an empty `SimpleActionGroup` named `editor`. Nothing uses it today,
  which makes it cheap to build and still a row upstream shipped.
- **`open_on_app` loses the "user declined" branch.** Upstream `debug`s when
  the launcher returns false (`DocumentView.vala:123`); the port swallows both
  the false and the `GLib::Error` (`document_view.rb:208-215`).
- **The two-way binding is reimplemented and narrower.** Upstream's
  `BindingGroup` (`DocumentView.vala:85-100`) is `SYNC_CREATE | BIDIRECTIONAL`
  on seven properties; the port pushes with `load_rows` and pulls with
  `notify::text` behind a `@loading` guard (`document_view.rb:177-193`). That
  is a correspondence for the five entry rows and the two date rows — located
  — but the eighth binding, `original-file` → `file_launcher.file`, has no
  counterpart because the launcher is rebuilt per call, and the ninth,
  `title` → `root.title`, is the window-title gap above.

## Unit: date row — `src/DateRow.vala` + `src/gtk/date-row.ui` → `date_row.rb`

| Widget | Up × | Port × | CSS | Signals | Text | Verdict |
|---|---:|---:|---|---|:-:|---|
| `Adw.ActionRow` | 1 | 1 | — | — | ✗ unmarked | **gap**: text |
| `Gtk.Button` | 3 | 3 | ✓ `flat` ×1 | ✓ `clicked` ×3 | ✗ unmarked | **gap**: text |
| `Gtk.MenuButton` | 1 | 1 | ✓ `flat` | — | ✗ unmarked | **gap**: text |
| `Gtk.Popover` | 1 | 1 | — | — | — | parity |
| `Gtk.Box` | 2 | 2 | ✓ `linked` | — | — | parity |
| `Gtk.Calendar` | 1 | 1 | — | ✓ `day-selected` | — | parity |

Gaps:

- **Both icons were substituted without the question being asked.** Upstream's
  clear button uses its own bundled `entry-clear-symbolic`
  (`src/gtk/entry-clear-symbolic.svg`, `date-row.ui`); the port uses the stock
  `edit-clear-symbolic` (`date_row.rb:21`). The calendar menu button upstream
  carries no icon name in the `.ui` at all — it is the default
  `view-more-symbolic` — and the port sets `x-office-calendar-symbolic`
  (`date_row.rb:22`). Two different glyphs in the same row.
- **Today and Tomorrow set a time of day upstream does not.** Upstream's
  handlers use `new DateTime.now_local()` and add a day; the port's
  `change_date(Time.now)` keeps the clock, and `on_day_selected` builds
  `Time.new(y, m, d)` at midnight (`date_row.rb:109`), discarding the hour,
  minute and second the PDF recorded whenever the user touches the calendar.
  The class comment at `date_row.rb:16-19` claims the `@syncing` guard
  prevents exactly this, and it prevents only the *programmatic* case.

## Unit: details list — `src/DetailsList.vala` + `src/gtk/details-list.ui` → `details_list.rb`

| Widget | Up × | Port × | CSS | Signals | Text | Verdict |
|---|---:|---:|---|---|:-:|---|
| `Adw.Bin` (template root) | 1 | 0 | — | — | — | correspondence: the root is the `Gtk.ListBox` (`details_list.rb:52`) |
| `Gtk.ListBox` | 1 | 1 | ✓ `boxed-list` | — | — | parity |
| `Adw.ActionRow` | 7 | 7 (repeater over `TITLES`) | ✓ `property` ×7 | — | ✗ unmarked | **gap**: text |
| `StringArrayRow` | 2 | 2 | — | — | ✗ unmarked | **gap**: text |

Gaps:

- **The page-count row's conditional visibility was removed.** Upstream shows
  `pages_row` only when `n_pages > 0` and hides it otherwise
  (`DetailsList.vala:60-66`); `details_list.rb:40-48` always sets a subtitle
  and `build` always appends the row. A PDF whose page tree this port fails to
  count now reads "Number of Pages: 0" instead of not claiming anything. The
  code comment at `details_list.rb:15-18` calls this "One deliberate
  difference"; see `.reports/accountability.md`.
- **`Yes` / `No` are unmarked** (`details_list.rb:31-32`); upstream marks both
  (`DetailsList.vala:56-59`).

## Unit: string array row — `src/StringArrayRow.vala` → `string_array_row.rb`

| Widget | Up × | Port × | CSS | Verdict |
|---|---:|---:|---|---|
| `Adw.ExpanderRow` | 1 | 1 | — | parity |
| `Gtk.ListBoxRow` (`ContentRow`) | 1 | 1 | — | parity |
| `Gtk.Label` | 1 | 1 | ✓ `dim-label` | parity |

Bullet format `"• %s\n"`, halign start, margin-start 12, margin-top 18 all
match. **This unit has parity** — it is the only one that does, and it shows
no text of its own.

## Unit: keyword list — `src/KeywordList.vala` + `src/gtk/keyword-list.ui` → `keyword_list.rb`

| Widget | Up × | Port × | CSS | Signals/actions | Text | Verdict |
|---|---:|---:|---|---|:-:|---|
| `Adw.PreferencesGroup` | 1 | 1 | — | — | ✗ unmarked | **gap**: text |
| `Gtk.Button` (add) | 1 | 1 | ✓ `flat` | ✓ `keyword-list.add-keyword` | ✗ unmarked | **gap**: text |
| `Gtk.ListBox` | 1 | 1 | ✓ `boxed-list` | ✓ `row-activated` | — | parity |
| `Gtk.ShortcutController` + `Gtk.Shortcut` | 1 + 1 | 1 + 1 | — | ✓ `<Control>Return` | — | parity |
| `KeywordRow` | n | n | — | — | ✗ unmarked | **gap**: text |
| `Adw.PreferencesRow` (empty state) | 1 | 1 | — | ✓ activatable | ✗ unmarked | **gap**: text |
| `Gtk.CenterBox` | 1 | 1 | — | — | — | parity |
| `Gtk.Label` | 1 | 1 | — | — | ✗ unmarked | **gap**: text |
| `Gtk.Image` | 1 | 1 | — | — | — | parity |
| `items-changed` on the keyword model | 1 | **0** | — | ✗ | — | **gap** |

Gaps:

- **`bind_model` became a manual rebuild, and the model notification is
  gone.** Upstream binds the list box to `document.keywords` and connects
  `items-changed` (`KeywordList.vala:41-44`), so anything that changes the
  keyword list updates the UI. The port rebuilds in `refresh`
  (`keyword_list.rb:147`) and only the three call sites it knows about reach
  it. A keyword added anywhere else — a future undo, a paste, a reload —
  leaves the list stale.
- **Rebuilding on delete destroys and recreates every row.** `refresh` clears
  the list box and rebuilds it (`keyword_list.rb:147-154`), so deleting one
  keyword while editing another throws away the focused widget. Upstream's
  `bind_model` only removes the one row.
- **The zero-to-one focus branch is missing.** Upstream focuses the first
  child when the count becomes 1 (`KeywordList.vala:108-110`) *and* focuses
  the last row on every other change (`KeywordList.vala:104`). The port
  focuses `list_box.last_child` after an add only (`keyword_list.rb:132`) and
  never after a delete.
- **`is_empty` is a property upstream, read by the `.ui` to invert the add
  button's visibility** (`keyword-list.ui`, `KeywordList.vala:33`). The port
  recomputes `add_button.visible` inside `refresh` (`keyword_list.rb:152`).
  Correspondence — located — but it is now unobservable from outside.

## Unit: keyword row — `src/KeywordRow.vala` → `keyword_row.rb`

| Widget | Up × | Port × | CSS | Signals | Text | Verdict |
|---|---:|---:|---|---|:-:|---|
| `Adw.EntryRow` | 1 | 1 | — | ✓ `notify::text` | ✗ unmarked | **gap**: text |
| `Gtk.Button` (delete) | 1 | 1 | ✓ `flat` | ✓ `clicked` | ✗ unmarked | **gap**: text |

Gap: **the icon was swapped.** Upstream ships `cross-symbolic`
(`src/gtk/cross-symbolic.svg`) in its gresource and uses it; the port uses the
stock `window-close-symbolic` (`keyword_row.rb:17`). The port ships none of
upstream's five bundled symbolic icons, so this is one of four icon
substitutions in the app.

## Unit: drop overlay — `src/DropOverlay.vala` → `drop_overlay.rb`

| Widget | Up × | Port × | CSS | Signals | Verdict |
|---|---:|---:|---|---|---|
| `Adw.Bin` | 1 | 1 | — | — | parity |
| `Gtk.Overlay` | 1 | 1 | — | — | parity |
| `Gtk.Revealer` | 1 | 1 | ✓ `overlay-drag-area` on the overlaid widget | ✓ `notify::current-drop` | parity |

**Count, style and behaviour match.** Text axis: this unit shows none.
Not marked `parity` only because nothing drove the drop and nothing
screenshotted the tint.

## Unit: save-changes dialog — `src/SaveChangesDialog.vala` + `src/gtk/save-changes-dialog.ui` → `save_changes_dialog.rb` + `document_row.rb`

| Widget | Up × | Port × | CSS | Signals | Text | Verdict |
|---|---:|---:|---|---|:-:|---|
| `Adw.MessageDialog` → `Adw.AlertDialog` | 1 | 1 | ✓ `destructive`, `suggested` | ✓ `response` | ✗ unmarked | correspondence on the type (deprecated in libadwaita 1.6); **gap** on text |
| `Gtk.ScrolledWindow` | 1 | 1 | — | — | — | parity |
| `Gtk.ListBox` | 1 | 1 | ✓ `boxed-list` | — | — | parity |
| `DocumentRow` | n | n | — | ✓ `active` | ✗ unmarked | **gap**: text, and below |
| `Gtk.CheckButton` | 1/row | 1/row | — | ✓ | — | parity |

Gaps:

- **The row title falls back to the basename.** Upstream shows
  `document.title` even when it is empty (`SaveChangesDialog.vala`);
  `document_row.rb:40-46` substitutes the filename. The port's behaviour is
  nicer and it is a divergence in a user-visible row, recorded here, and the
  comment at `document_row.rb:15-17` presents it as a decision — see
  `.reports/accountability.md`.
- **`selected_documents` returns a `ListModel` upstream and an Array here**
  (`save_changes_dialog.rb:52`), which is a correspondence; but the one caller
  that matters, `Window#save_selected`, ignores it. See the window unit.
- The three response labels `_Cancel`, `_Discard`, `_Save` and the heading and
  body are byte-identical to upstream and **unmarked**.

## Units with no port file at all

| Upstream unit | What the user loses |
|---|---|
| `src/PasswordDialog.vala` + `src/gtk/password-dialog.ui` | An encrypted PDF cannot be opened in this port. Upstream asks for the password in a dialog titled "Password Dialog", with a `compact` `Adw.StatusPage` reading "This Document Is Encrypted" over the filename, an `Adw.PasswordEntryRow` titled "Password", a `pill suggested-action` "Decrypt" button, `Return` and `Escape` bound in the capture phase, and a `closed` handler that cancels the in-flight task. 12 widgets, 4 CSS classes, 2 actions, 2 signals, 4 msgids: none of it exists. |
| `src/Models/AsyncTask.vala` | The suspend/resume the password dialog used. Follows the above. |
| `src/DocumentThumbnail.vala` | The page-one preview. See the editor-page unit. |
| `src/Services/Thumbnailer.vala` | The off-thread Poppler render, the white backing rectangle, the filter choice and the `$TMPDIR/thumbnails` PNG cache behind it. |
| `data/*.desktop.in` | There is no desktop entry, so the port does not appear in a launcher, is not associated with `application/pdf`, and its `New Window` desktop action does not exist. Three msgids with it. |
| `data/*.metainfo.xml.in` | No AppStream data, so no software-centre listing, name, summary or screenshots. Three msgids. |
| `data/*.gschema.xml` | Upstream's schema is empty, so nothing is lost behaviourally — but the file is absent and the fact that it is empty is recorded here rather than assumed. |
| `data/*.service.in` | No D-Bus activation. |
| `data/icons/**` | The app has no icon. `window.rb:196` and `about_dialog.rb:34` both reference `io.github.diegoivan.pdf_metadata_editor`, which this port does not install, so the welcome page and the About dialog show a missing-image placeholder on any machine that does not already have upstream installed. |
| `src/gtk/*.svg` | The five bundled symbolic icons. Four substitutions and one unused pair. |
| `data/nautilus-extension/paper-clip.py` | No "Edit pdf metadata…" entry in the Nautilus context menu. One msgid. |
| `po/**` | See `.reports/translation-parity.md`. |

## Document and services

Not widget units, and the app does nothing without them.

- **`cached_file` does not exist.** Upstream copies the original into
  `$TMPDIR/copies` before opening it and edits the copy
  (`Document.vala:467-495`), writing out to the chosen URI on save. The port
  reads `File.binread(path)` (`document.rb:98`) and `save_async` appends an
  incremental update — so an interrupted or failed save in the port can leave
  the user's original file damaged, where upstream's worst case is a damaged
  temp copy. This is the most dangerous gap in the port.
- **XMP is read and never written.** Upstream mirrors producer, creator,
  keywords, title, CreateDate, ModifyDate and MetadataDate into the XMP packet
  on every save of a file that has one (`Document.vala:227-270`). The port
  reads the packet for `subtype` and `has_xmp?` (`document.rb:198-199`) and
  writes nothing. A PDF/A file edited in this port now disagrees with itself:
  the Info dictionary says one author and the XMP says another, and every
  standards-aware reader believes the XMP.
- **`get_page_for_index` has no counterpart**, which is the thumbnail gap at
  the model layer.
- `ThreadManager`, `DocumentManager`, `PdfStrings` and `Style` correspond and
  are located; `PdfStrings` reproduces all 29 of upstream's enum strings,
  unmarked.

## Summary

| | |
|---|---|
| Units compared | 17 |
| Units with every row `parity` | 0 |
| Units whose only open row is the text axis | 2 (`string_array_row`, `drop_overlay` — and neither was driven) |
| Upstream units with no port file | 6 (+ 6 packaging files) |
| Distinct behaviour gaps named above | 29 |
| Signals driven | 0 |
| Screenshots taken | 0 |
