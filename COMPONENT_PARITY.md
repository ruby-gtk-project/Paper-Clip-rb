# Component parity — Paper-Clip-rb

| | |
|---|---|
| Upstream | `origin/main` @ `c4db98e0bc2b8921d78c9e3fbf3d85ad2a124bd0` |
| Port | `ruby` branch, round 2 |
| Units compared | 21 |
| Units with no port file at all | **2** (was 6) |
| Driven (signals actually fired) | **0** — no driver run exists |
| Screenshots | **none** |

The file map is in `PORTING.md`. Costs and open questions are in
`FINDINGS.md`. Message keys are in the translation section at the foot of this
file.

## Two things this ledger cannot claim, and does not

- **Nothing was driven.** Step 5 of the component-parity skill is unsatisfied
  for every unit. Every behaviour row below is a static reading of source; a
  handler connected to an empty method would pass it. GTK cannot initialise
  in this environment — no display, no `Xvfb` — so the driver in
  `.claude/skills/ruby-gtk-testing` has never run. `FINDINGS.md` §8 has the
  diagnosis and the one-line fix.
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

- **The debug block cannot print a Poppler or an Exempi version**, because the
  port links neither. GdkPixbuf, Gtk, Libadwaita and Ruby are printed, and the
  two absences are stated in the block itself. The cost is `FINDINGS.md` §1
  and §2.
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

Open on this unit:

- **Save writes to a path, upstream to a URI.** Upstream saves to
  `document_manager.document.original_file.get_uri()`
  (`window.vala:211`); the port saves to `document.path`, because
  `File.binwrite` takes a path. A document opened over GVFS therefore saves
  to the local path GIO reports, or not at all. Recorded; closing it means a
  `Gio::File.replace` writer.
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
| `DocumentThumbnail` | 1 | **0** | ✗ `icon-dropshadow` | — | — | **gap** |
| `Gtk.Label` (title) | 1 | 1 | ✓ `title-1`, `long-filename` | — | — | parity |
| `Adw.PreferencesGroup` | 2 | 2 | — | — | ✓ | parity |
| `Adw.EntryRow` | 5 | 5 | — | ✓ `notify::text` | ✓ | parity |
| `DateRow` | 2 | 2 | — | ✓ | ✓ | parity |
| `KeywordList` | 1 | 1 | — | — | — | parity |
| `DetailsList` | 1 | 1 | — | — | — | parity |
| `Gtk.ShortcutController` + `Gtk.Shortcut` | 1 + 2 | 1 + 2 | — | ✓ | — | parity |
| `Gtk.FileLauncher` | 1 | 1 | — | ✓ incl. the declined branch | — | correspondence: one per launch, where upstream keeps one and binds `original-file` to it |
| `editor` action group | 1 | 1 | — | ✓ | — | parity |
| `document.title` → `root.title` | 1 | 1 | — | ✓ | — | parity |

The gap: **the page-one preview is not built.** Upstream shows a rendered
thumbnail of page 1 above the filename (`document-view.ui:25`,
`src/DocumentThumbnail.vala`, `src/Services/Thumbnailer.vala`): a white
background rectangle under the page so transparent PDFs are visible, a
`Gtk.Snapshot` scale with `NEAREST` upscaling and `TRILINEAR` downscaling,
`MAX_SIZE = 350`, and a PNG downscale cache in `$TMPDIR/thumbnails` for pages
bigger than `max_size² × 2.5`. The port shows nothing there, so a user cannot
confirm they opened the right PDF before editing it, and the
`icon-dropshadow` class on that image is attached nowhere. The class comment
on `DocumentView` states it in the first person; `FINDINGS.md` §1 holds the
cost.

The two-way binding remains a correspondence: upstream's `BindingGroup` is
`SYNC_CREATE | BIDIRECTIONAL` on eight properties; the port pushes with
`load_rows` and pulls with `notify::text` behind a `@loading` guard. Seven of
the eight are located, the eighth (`original-file` → `file_launcher.file`) has
no counterpart because the launcher is rebuilt per call, and the window title
is now a ninth push rather than a bind.

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
| `src/DocumentThumbnail.vala` | the page-one preview. See the editor-page unit and `FINDINGS.md` §1 |
| `src/Services/Thumbnailer.vala` | the off-thread render, the white backing rectangle, the filter choice and the `$TMPDIR/thumbnails` PNG cache behind it |
| `data/*.service.in` | no D-Bus activation, although the desktop entry still declares `DBusActivatable=true` — which makes this a live inconsistency, not just an absence |
| `src/pdf-metadata-editor.gresource.xml` | nothing: a Ruby port has no gresource, and the icons it carried are installed as a filesystem icon theme |

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
| `get_page_for_index` | **gap**, which is the thumbnail gap at the model layer |
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
| Units compared | 21 |
| Upstream units with no port file | 2 (+ 1 packaging file) |
| Distinct behaviour gaps named above | 4 — the thumbnail, its model-layer accessor, D-Bus activation, and saving to a path rather than a URI |
| Message keys | 96 / 96, 0 gaps |
| Signals driven | **0** |
| Screenshots taken | **0** |

The last two lines are the ones that decide how much the rest is worth.
