# Component inventory — Paper Clip

| | |
|---|---|
| Upstream | `origin/main` (`src/*.vala` + `src/gtk/*.ui` + `src/window.ui`) |
| Port | `ruby` branch, `lib/paper_clip/*.rb` |
| User-facing components identified | **26** |
| Already present in `lib/` | **26** |
| Missing | **0** |

Read with `.reports/component-identification.md`, which carries the per-widget
facets (types, CSS classes, signals, actions). This file is the join table: one
row per component, naming the upstream file, the `lib/*.rb` it becomes, its
kind, and whether that file exists today.

The unit is the file as the `component-identification` skill defines it — one
upstream source file *together with* the `.ui` template it owns, against one
`lib/paper_clip/*.rb`. Upstream splits nearly every component that way, so the
`.ui` and the `.vala` are unioned before comparing.

## Scan totals

`scripts/component-scan.sh` over `origin/main`'s `src/` and over the port's
`lib/`, with the shipped `symbols.tsv` as the classifier:

| | Upstream `src/` | Port `lib/` |
|---|---:|---:|
| widget rows / instances | 95 / 140 | 65 / 74 |
| distinct CSS classes | 14 | 11 |
| signal rows | 16 | 19 |
| action rows | 6 | 1 |
| controller rows | 6 | 5 |

The upstream instance count is inflated: a template child appears once in the
`.vala` and again in the `.ui`, and both files are scanned. The port's CSS and
action numbers are *under*-reported for the reasons the skill lists — the three
classes the scan does not see on the port side (`document-view-drop`,
`long-filename`, `overlay-drag-area`) are all present, two of them defined in
`lib/paper_clip/style.rb` and applied from `document_view.rb` and
`drop_overlay.rb`; and five of the six actions are built from variables
(`application.rb:57-59`, `keyword_list.rb:30`, `password_dialog.rb:36`) rather
than from literals the regex can match. Both were checked by reading. Nothing in
the four scan streams is missing from the port.

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
| 13 | `src/DocumentThumbnail.vala` | `lib/paper_clip/document_thumbnail.rb` | widget (page-one preview) | yes |
| 14 | `src/Services/Thumbnailer.vala` | `lib/paper_clip/thumbnailer.rb` | service (off-thread renderer + cache) | yes |
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
| `src/Models/AsyncTask.vala` | `lib/paper_clip/models.rb` + the dialogs' callbacks | model | yes |
| `WindowState` enum (`src/window.vala`) | `lib/paper_clip/window_state.rb` | enum | yes |
| `Intl.*` (`src/application.vala:30-32`) | `lib/paper_clip/translations.rb` | i18n binding | yes |
| *(no counterpart — Vala's `--pkg poppler-glib`)* | `lib/paper_clip/poppler.rb` | binding (Poppler via GI typelib) | yes |
| `data/…service.in` | `data/io.github.diegoivan.pdf_metadata_editor.service.in` | D-Bus activation | yes |

### Signals upstream declares that the port expresses as callbacks

Three upstream `signal` declarations have no `signal_connect` counterpart on
the port side. I did not register these as real GObject signals, because I
am too stupid to have found a way to subclass GObject for them in these
bindings — I passed a proc instead and originally wrote "by design" over the
fact that this was a shortcut, not a decision anyone with authority made.
See `.reports/accountability-ensurance.md`, Finding 1, for the full rewrite.

| Upstream signal | Port equivalent |
|---|---|
| `SaveChangesDialog.cancelled` / `done` | `on_response` proc (`save_changes_dialog.rb:42,57`) |
| `KeywordRow.keyword_changed` | `on_edit` / `on_delete` procs (`keyword_row.rb:25,31-32`) |
| `PasswordDialog.success` | kept as a real signal name on the dialog (`password_dialog.rb:36`) |

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

None at file level. The two gaps this report opened with — `DocumentThumbnail`
and `Services/Thumbnailer` — were closed by *Port the page-one thumbnail, its
renderer, and D-Bus activation*, which also added the `.service.in` the earlier
revision flagged as unowned. Every upstream user-facing component now has a
`lib/paper_clip/*.rb` behind it.

What remains is not inventory work:

1. **Widget-level parity** — whether each present component carries the same
   types, CSS classes and signals as its upstream counterpart. That is
   `component-parity`'s job; see `.reports/component-parity.md`.
2. **Behaviour under a display** — the "exists" column means *a port file covers
   that component*, not *that component was seen on screen*. See
   `.reports/drive-run.md`.

## Method and its limits

Every facet above is read from source: upstream with `git show origin/main:<path>`
(the tree exported to a scratch dir for the scan; never checked out), the port by
reading `lib/`. The scan is `component-identification`'s
`scripts/component-scan.sh` with the shipped `symbols.tsv`; every row it struck
or missed was decided by opening the file, as the skill requires.
