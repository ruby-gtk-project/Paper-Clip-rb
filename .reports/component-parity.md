# Component parity — Paper Clip

| | |
|---|---|
| Upstream | `origin/main` @ `c4db98e0bc2b8921d78c9e3fbf3d85ad2a124bd0` (2025-04-28) |
| Port | `ruby` branch, this audit |
| Units compared | 13 upstream widget units → 12 port files |
| Units at parity on all four axes (by reading) | 10 |
| Units with gaps | **3** |
| Axes confirmed by running the app | **0 of 4** |

Four axes per unit: **type**, **CSS classes**, **signals/handlers**, **actions** —
plus the text axis for every user-visible string (that one is settled in
`translation-parity.md`: 96/96).

## Unit: application window — `src/window.ui` + `src/window.vala` → `lib/paper_clip/window.rb`

| Axis | Upstream | Port | Verdict |
|---|---|---|---|
| type | `AdwApplicationWindow` 600×500 / 350×320, `AdwToolbarView`, `AdwHeaderBar`, `GtkProgressBar`, `AdwToastOverlay`, `DropOverlay`, `GtkStack` crossfade, `AdwClamp`, `GtkImage` 128, 2 labels, `AdwButtonContent`, `GtkMenuButton` | all present, same sizes, same order (`window.rb:79-120`, `:150-230`) | ✅ |
| css | `.osd` on the progress bar, `.icon-dropshadow` on the welcome icon, `.title-1` on *Open a Document* | all three (`:190`, `:223`, `:228`) | ✅ |
| signals | `close-request`→`on_close_request`, `drop`→`on_file_dropped`, `TimedAnimation::done` | all three (`:115`, `:117`, `:562`) | ✅ |
| actions | `win.open`, `win.open-with`, `win.save`, `win.save-as`, `win.main-menu`; three start disabled; shortcuts `<Control>o`/`<Control>w`/`F10` | identical, `DOCUMENT_ACTIONS` disabled in `setup_actions` (`:57`, `:256-259`) | ✅ |

Behaviour read as equivalent: the `WindowState` machine, `proceed_with_state`,
the pulse and the 200 ms `EASE_IN_OUT_SINE` fraction/opacity animations, the
single wrong-password toast, the `critical`→`warn` logging of every other
failure, `Gtk::FileDialog` with the one unnamed-dialog PDF filter.

## Unit: primary menu — `window.ui` `<menu>` → `lib/paper_clip/primary_menu.rb`

All eight attributes reproduced: three sections, the three `hidden-when="action-disabled"`
items, both `accel` attributes, mnemonics inside the translatable strings. ✅

## Unit: application — `src/application.vala` → `lib/paper_clip/application.rb`

Actions `about`/`shortcuts`/`query-quit`/`new-window` with the same three
accels; `HANDLES_OPEN`; `open()` one window per PDF with non-PDFs logged;
the two-stage `query-quit`. `Xmp.init`/`terminate` have nothing to call — the
port has no exempi binding — and that is a mechanism difference, not a
behaviour one. ✅

`AboutDialog` reproduces every `AdwAboutDialog` property including
`translator_credits` and `debug_info`. The debug block drops upstream's
Poppler and Exempi version lines; see **Gap 4**.

## Unit: editor page — `src/DocumentView.vala` + `.ui` → `lib/paper_clip/document_view.rb`

| Axis | Verdict |
|---|---|
| type | **GAP** — see Gap 1. `AdwBin` wrapper collapsed into the `ScrolledWindow` (a correspondence, the tree is otherwise identical); 5 `AdwEntryRow` + 2 `DateRow` in upstream's order; both `AdwPreferencesGroup`s present |
| css | `.document-view-drop` on the clamp, `.title-1` on the filename label, `.long-filename` applied on the same two thresholds (45 + space, 21 without) ✅ |
| signals | `notify::text` × 5 + the title push, `DateRow#on_change` × 2, `FileLauncher#launch` callback ✅ |
| actions | `<Control>s`→`win.save`, `<Control><Shift>s`→`win.save-as`; empty `editor` action group inserted ✅ |

### Gap 1 — the page-one preview does not exist

Upstream's editor page opens with a rendered thumbnail of page one.
The port's opens with the filename.

- Upstream: `src/gtk/document-view.ui:25` places `PaperClipDocumentThumbnail`
  with `margin-top 12`; `src/DocumentThumbnail.vala:21-103` builds a
  `GtkImage` with `.icon-dropshadow` at `pixel_size 175`, snapshots the page
  over a white rectangle at `MAX_SIZE = 350` with `NEAREST`/`TRILINEAR`
  filtering; `src/Services/Thumbnailer.vala` renders it off the main loop and
  caches a downscaled PNG under `$TMPDIR/thumbnails`;
  `src/Document.vala:287-289` exposes `get_page_for_index`.
- Port: `lib/paper_clip/document_view.rb:95` appends `title_label` as the
  box's first child. `lib/paper_clip/document.rb` has no page accessor, no
  renderer, no cache. `grep -rn "thumbnail" lib/` returns only comments.
- Cost to the user: a user cannot see which PDF they opened before they start
  editing its metadata. Opening the wrong file, or a file whose first page is
  blank or transparent, looks exactly like opening the right one — and the
  metadata they then overwrite is the wrong document's.

The port's own comment at `document_view.rb:30-41` admits this in the required
form. It is still a gap, and it is the largest one in the port.

### Gap 2 — `Services/Thumbnailer` has no counterpart at all

Separate from Gap 1 because it is its own unit and carries its own
user-visible behaviour: upstream degrades gracefully on a huge page by
writing a PNG and reloading it at a reduced size, and reports
`FAILED_EXPORT` / `FAILED_TO_CACHE` when the cache directory cannot be
written. The port has neither path, so there is nothing to degrade and
nothing to report. `ThreadManager` exists (`lib/paper_clip/thread_manager.rb`)
and is used by `Document#save_async`, so the off-thread half of the mechanism
is in place and unused by any renderer.

## Unit: details list — `src/DetailsList.vala` + `.ui` → `lib/paper_clip/details_list.rb`

Nine rows in upstream's order; `.boxed-list` on the list box, `.property` on
all seven action rows, `selectable = false` on all nine; *Yes*/*No*; pages row
hidden at zero with no stale subtitle. ✅
One difference: the port sets `selection_mode = :none` on the list box where
upstream's `.ui` leaves the default. With every row `selectable = false` the
visible result is the same; recorded, not counted.

## Unit: string-array row — `src/StringArrayRow.vala` → `lib/paper_clip/string_array_row.rb`

`AdwExpanderRow` + `ContentRow : GtkListBoxRow` → `.dim-label` label,
halign START, margin-start 12, margin-top 18, `"• %s\n"` join. ✅

## Unit: date row — `src/DateRow.vala` + `.ui` → `lib/paper_clip/date_row.rb`

Both suffixes with `.flat` and both tooltips, the popover, the calendar, the
`.linked` homogeneous *Today*/*Tomorrow* box, `%x` subtitle, *No date set*,
zero-based calendar month. ✅
The port additionally carries the clock of the existing date through a
day-selection where upstream stores midnight (`date_row.rb:136-146`) — a
documented improvement over `src/DateRow.vala:47`, noted because it is a
behaviour difference even though it is the better one; it belongs in
`FINDINGS.md` as a proposal.

## Unit: keyword list — `src/KeywordList.vala` + `.ui` → `lib/paper_clip/keyword_list.rb`

Group title, header-suffix add button (`.flat`, `list-add-symbolic`, tooltip,
`keyword-list.add-keyword`), `.boxed-list` list box, `row-activated`,
`<Control>Return`, the action group, the full empty state (`AdwPreferencesRow`
→ `GtkCenterBox` → icon halign END hexpand margin-end 12 + *Add Keyword*
label), and both focus rules. ✅
The add button's `visible` is recomputed in `settle` instead of bound to an
`is-empty` property — a correspondence with the same result.

## Unit: keyword row — `src/KeywordRow.vala` → `lib/paper_clip/keyword_row.rb`

`AdwEntryRow`, `focusable`, title *Keyword*, `cross-symbolic` prefix button
with `.flat` and *Delete Keyword*. Deletion is by row identity rather than by
text — strictly better than upstream, which removes the first match and can
delete the wrong duplicate. ✅

## Unit: drop overlay — `src/DropOverlay.vala` → `lib/paper_clip/drop_overlay.rb`

Bin → overlay + overlaid revealer, `can_target = false`, `visible = false`,
CROSSFADE, `notify::current-drop`, `.overlay-drag-area` applied to the
overlaid widget. ✅

## Unit: password dialog — `src/PasswordDialog.vala` + `.ui` → `lib/paper_clip/password_dialog.rb`

350×320, title, `show-title = false` header, `.compact` status page with
`key-symbolic` and the basename description, `.boxed-list` list box,
`AdwPasswordEntryRow`, `.pill .suggested-action` Decrypt button, the `dialog`
action group, the **capture-phase** Return/Escape controller, and `closed`
→ cancel with the once-only guard standing in for
`requires (task.status == RUNNING)`. ✅

## Unit: save-changes dialog — `src/SaveChangesDialog.vala` + `.ui` → `lib/paper_clip/save_changes_dialog.rb` + `document_row.rb`

Heading, body, three responses with destructive/suggested appearances,
default `save`, close `cancel`, the scrolled `.boxed-list` list box, and
`DocumentRow` with its valign-center check button checked by default and
`document.title` as the row title. `AdwMessageDialog` → `AdwAlertDialog` is
the documented libadwaita 1.6 replacement, not a gap. ✅

## Unit: shortcuts — `src/gtk/shortcut-window.ui` → `lib/paper_clip/shortcuts_dialog.rb`

Two groups, all eight shortcuts, all ten strings with `msgctxt "shortcut window"`.
`GtkShortcutsWindow` (deprecated in GTK 4.18) → `AdwShortcutsDialog`; the
section's `max-height = 10` has no Adwaita counterpart because the dialog
paginates itself. ✅

## Unit: stylesheet — `src/style.css` → `lib/paper_clip/style.rb`

All three rules byte-identical, loaded at `PRIORITY_APPLICATION`. ✅
`.document-view-drop` is applied by both sides and defined by neither —
an upstream bug the port correctly reproduces rather than silently fixes.

## Gap 3 — no D-Bus service file, so the app is not D-Bus activatable

- Upstream: `data/io.github.diegoivan.pdf_metadata_editor.service.in` plus
  `data/meson.build:43-50` install
  `share/dbus-1/services/io.github.diegoivan.pdf_metadata_editor.service`
  with `Exec=@bindir@/pdf-metadata-editor --gapplication-service`.
- Port: no `data/*.service.in`; `flake.nix` installs applications, metainfo,
  icons and schemas and no D-Bus service.
- Cost to the user: anything that starts the app by its bus name — a portal,
  a file manager using activation rather than `Exec=`, `gdbus call` — gets
  nothing. `--gapplication-service` itself still works when invoked by hand.

## Gap 4 — the About dialog's debug block cannot name the PDF or XMP library

- Upstream: `src/application.vala:196-215` prints `Poppler <version> (Compile Time)`
  and `Exempi <version>`.
- Port: `lib/paper_clip/about_dialog.rb:66-67` prints two sentences saying
  neither is linked.
- Cost to the user: a bug report copied out of the About dialog no longer
  tells a maintainer which PDF stack produced the behaviour. The port's own
  stack is Ruby code with no version of its own to print, so the honest fix is
  to print the port's `Document`/`XmpPacket` revision, not to omit the lines.
  Smallest gap in this report, and the only one whose remedy is a one-line
  string.

## Gap 5 — nothing on the port side has been confirmed to render or fire

Steps 4 and 5 of the skill — *confirm the styling actually renders* and
*confirm the behaviour actually fires* — **did not run.**

```
$ nix develop --command ruby -e 'require "adwaita"'
gtk4/loader.rb:37: failed to initialize GTK (Gtk::InitError)
$ which xvfb-run Xvfb   ->  nothing
```

There is no display and no X server in the closure or on the host, and GTK4
has no headless backend. Consequences, stated rather than implied:

- Every ✅ above is a reading of source. A handler wired to an empty method,
  a CSS class added to a widget that was never parented, a `tap` block whose
  memoized accessor is shadowed — all of them pass a reading.
- The port builds the window as `Adwaita::ApplicationWindow`
  (`window.rb:151`). The `ruby-gtk` skill records `Adwaita::Application` and
  `Adwaita::ApplicationWindow` as **broken in these bindings** and prescribes
  `Gtk::ApplicationWindow`. The port's comment at `window.rb:142-149` argues
  for the Adwaita class on the merits and does not say it was ever
  instantiated. If the skill is right, the window does not open at all and
  every other verdict in this document is moot. **This is the single highest-value
  thing to settle**, and it cannot be settled by reading.
- `spec/` contains no widget test of any kind, so nothing in the repository
  constructs a single `Adwaita::` object. The vendored
  `.claude/skills/ruby-gtk-testing` driver has never been run.
- Remedy: add `pkgs.xvfb-run` (or `pkgs.xorg.xorgserver`) to the devShell —
  a one-line `flake.nix` change — then drive each unit and screenshot it.

## Rules observed

- No unit was marked at parity on the strength of the scan alone; every one
  above was read on both sides.
- Platform classes (`flat`, `osd`, `pill`, `boxed-list`, `title-1`,
  `dim-label`, `property`, `compact`, `suggested-action`, `linked`,
  `icon-dropshadow`) were not reported as missing stylesheet rules.
- The two unrun axes are named as unrun, not reported as passed.
