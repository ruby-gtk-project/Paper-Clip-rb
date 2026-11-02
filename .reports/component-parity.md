# Component parity — Paper Clip

| | |
|---|---|
| Upstream | `origin/main` @ `c4db98e0bc2b8921d78c9e3fbf3d85ad2a124bd0` (2025-04-28) |
| Port | `ruby` @ `3800624` |
| Widget units compared | 15 → 15 |
| Widget units with no port file | **0** |
| Units at parity on all four axes | **15** |
| Axes confirmed by running the app | **4 of 4** — type, CSS, signals/actions by assertion; style by screenshot |
| Driven | `nix develop --command xvfb-run -a ruby test/drive_paper_clip.rb` → **278 of 278 checks passed, `DRIVE OK`** (re-run for this audit, exit 0) |
| Screenshots | 18 under `tmp/shots/`, four opened and read for this audit |
| Gaps | **3** (all outside the widget tree) |

Four axes per unit: **type**, **CSS classes**, **signals/actions**, **text**.
The text axis is settled in `translation-parity.md`: 96 of 96 upstream msgids
exist in the port's source, byte-identical, with contexts.

This is the first round in which Steps 4 and 5 of the skill actually ran. Last
round's copy of this document said *"Axes confirmed by running the app: 0 of
4"* and *"the port builds the window as `Adwaita::ApplicationWindow` … the
`ruby-gtk` skill records it as broken in these bindings … if the skill is
right, the window does not open at all and every other verdict in this
document is moot."* It is not right here: the window opens, and
`tmp/shots/01-welcome.png` is a picture of it.

## Unit: application window — `src/window.ui` + `src/window.vala` → `window.rb`

| Axis | Upstream | Port | Verdict |
|---|---|---|---|
| type | `AdwApplicationWindow` 600×500 / 350×320, `AdwToolbarView`, `AdwHeaderBar`, `GtkProgressBar`, `AdwToastOverlay`, `DropOverlay`, `GtkStack` crossfade, `AdwClamp`, `GtkImage` 128, 2 `GtkLabel`, `AdwButtonContent`, `GtkMenuButton` | all present, same sizes, same order | parity |
| css | `.osd`, `.icon-dropshadow`, `.title-1` | all three; `tmp/shots/01-welcome.png` shows the title at display size and the icon with its shadow | parity |
| signals | `close-request`, `drop`, `TimedAnimation::done` | all three. **Driven**: step 50 refuses a non-PDF drop, step 52 accepts a PDF, steps 80–84 block and then allow a close | parity |
| actions | `win.open`/`open-with`/`save`/`save-as`/`main-menu`, three start disabled; `<Control>o`, `<Control>w`, `F10` | identical. **Driven**: step 3 enumerates every action and accelerator, step 4 the three shortcuts, step 6 pops the menu | parity |

The progress bar's 200 ms `EASE_IN_OUT_SINE` fraction and opacity animations
are asserted at both ends (steps 0, 13, 55 — `opacity.zero?` at rest, `< 1`
after the fade). The single wrong-password toast is asserted by title at
step 64.

## Unit: primary menu — `window.ui` `<menu>` → `primary_menu.rb`

Three sections, eight items, both `accel` attributes, all three
`hidden-when="action-disabled"`, mnemonics inside the translatable strings.
**Driven**: step 5 reads the model back section by section; step 7 confirms
the popover is showing. `tmp/shots/02-primary-menu.png`. parity

## Unit: application — `src/application.vala` → `application.rb`

`about`/`shortcuts`/`query-quit`/`new-window` with upstream's three accels;
`HANDLES_OPEN`; one window per PDF with non-PDFs logged; the two-stage
`query-quit`. **Driven**: steps 85–91 run the application as a *child
process* with file arguments — one PDF, a refused non-PDF, two PDFs — because
`Gio::Application#open` cannot be called or emitted from Ruby. parity

## Unit: About dialog — `application.vala` `on_about_action` → `about_dialog.rb`

Every `AdwAboutDialog` property including `translator_credits` and
`debug_info`. **Driven**: steps 10–11, `tmp/shots/04-about.png`.
The debug block now prints a real Poppler version (`about_dialog.rb:67`),
which closes last round's Gap 4 by half. The Exempi line does not — see
**Gap 2**.

## Unit: editor page — `src/DocumentView.vala` + `.ui` → `document_view.rb`

| Axis | Verdict |
|---|---|
| type | parity. `DocumentThumbnail` is the box's first child (`document_view.rb:82`), then the title label, the two preference groups and the keyword list, in upstream's order. The `AdwBin` wrapper is collapsed into the `ScrolledWindow` — a correspondence, nothing attaches to the bin |
| css | parity. `.document-view-drop` on the clamp, `.title-1` on the filename, `.long-filename` on upstream's two thresholds. **Driven**: steps 56–59 assert the class appears on a 45-char name with a space and is replaced by `ellipsize=END` on a 21-char name without one, with screenshots |
| signals | parity. `notify::text` ×5 plus the title push, `DateRow#on_change` ×2. **Driven**: steps 20–22 type into each row and read the write-through off the document; step 21 reads the window title |
| actions | parity. `<Control>s`/`<Control><Shift>s`; the empty `editor` group is inserted and shadows nothing (step 98) |

## Unit: page preview — `src/DocumentThumbnail.vala` → `document_thumbnail.rb`

| Facet | Up | Port | Verdict |
|---|---|---|---|
| `Adw.Bin` root holding one `Gtk.Image` | 1 + 1 | 1 + 1 | parity. Driven, step 15 |
| `icon-dropshadow` on the image | ✓ | ✓ | parity |
| `MAX_SIZE = 350`, `pixel_size = MAX_SIZE / 2` | ✓ | ✓ | parity. Driven, step 15 |
| `margin-top = 12` | on the thumbnail in `document-view.ui:26` | on the image inside it (`document_thumbnail.rb:56`) | correspondence — the bin has no padding, so the gap lands in the same place |
| white backing rectangle under the texture | ✓ | ✓ `append_color` before `append_scaled_texture` | parity by reading |
| filter choice | NEAREST up / TRILINEAR down | same | parity by reading |
| `compute_scaled_size` (the AdwAvatar fill) | ✓ | ✓, including a portrait page overshooting `MAX_SIZE` | parity by reading |
| destructor clearing the image | 1 | 0 | correspondence: Ruby has no destructor |
| failure path | `critical`, image left cleared | `warn`, image left cleared | parity |

**What the driving does and does not establish.** Step 15 asserts
`image.paintable` is not nil and the bin wraps the image. The only page any
fixture builds is `<< /Type /Page /MediaBox [0 0 200 200] >>` with **no
`/Contents`** (`spec/support/pdf_fixtures.rb:41`) — a genuinely blank page. So
`tmp/shots/05-editor.png` shows a white square, which is correct here and is
also exactly what a thumbnailer that rendered nothing at all would produce.
The white backing rectangle, the filter choice and the fill arithmetic are
read, not observed. See **Gap 3**.

## Unit: thumbnail service — `src/Services/Thumbnailer.vala` → `thumbnailer.rb`

| Facet | Up | Port | Verdict |
|---|---|---|---|
| shared instance | `get_default` | `Thumbnailer.default` | parity. Driven, step 15 |
| `max_size` set by the caller, starting at zero | ✓ | ✓ | parity. Driven, step 15 |
| `area_threshold = 2.5` | ✓ | `AREA_THRESHOLD = 2.5` | parity by reading |
| memory format from byte order | B8G8R8A8 / A8R8G8B8, cached | same, cached | parity. **Driven**, step 15 asserts it against this machine's byte order |
| surface allocated before the render | ✓ | ✓ ARGB32 at the page's truncated size | parity |
| render off the main loop | ThreadPool, one worker | `ThreadManager`'s one worker, GVL released across `Poppler::Page#render` | correspondence; one job covers render and load where upstream awaits each. Driven, steps 94–95 |
| small page → memory texture | `Gdk.MemoryTexture` over a copy | same; `surface.data` is the copy | parity. Driven, step 15 |
| **big page → downscaled PNG** | `write_to_png`, then `from_file_at_size` | same code | parity **by reading only** — see **Gap 3** |
| step loop for the scale factor | 0.1 up by 0.1 while below 0.8 | same seven steps, else 0.8 | parity by reading |
| cache path | `$TMPDIR/thumbnails/<basename>.png` | same | parity by reading |
| cache directory mode | `0777` | `0700` | deliberate divergence, documented at `thumbnailer.rb:156-159`: a world-writable directory in a shared `/tmp`, named after the open document, is one another user can replace between the write and the read |
| `FAILED_EXPORT` / `FAILED_TO_CACHE` | 2 | `ExportError` / `CacheError` | parity by reading |

## Unit: details list — `src/DetailsList.vala` + `.ui` → `details_list.rb`

Seven `AdwActionRow`s in upstream's order (built from `TITLES` in a loop —
counted at the call sites), `.boxed-list` on the list box, `.property` and
`selectable = false` on all seven, the two `StringArrayRow`s after them,
*Yes*/*No*, and the pages row hidden at zero with no stale subtitle.
**Driven**: step 17 reads every subtitle; steps 54–55 open a PDF whose page
tree says nothing and assert the row is hidden rather than claiming zero
pages. The port sets `selection_mode = :none` where the `.ui` leaves the
default; with every row `selectable = false` the visible result is the same.
`AdwBin` root collapsed into the list box. parity

## Unit: string-array row — `src/StringArrayRow.vala` → `string_array_row.rb`

`AdwExpanderRow` + a `GtkListBoxRow` holding a `.dim-label` label, halign
START, margin-start 12, margin-top 18, `"• %s\n"` join.
**Driven**: steps 18–19 expand the permissions row and read its text.
`tmp/shots/06-details-expanded.png`. parity

## Unit: date row — `src/DateRow.vala` + `.ui` → `date_row.rb`

Both suffixes with `.flat` and both tooltips, the popover, the calendar, the
`.linked` homogeneous *Today*/*Tomorrow* box, `%x` subtitle, *No date set*,
zero-based calendar month. **Driven**: steps 16, 23–27 — the dates load,
a calendar day-selection moves the date, the *Today*/*Tomorrow* pair land a
day apart, and the clear button empties both the row and the document.
parity

One intentional divergence, recorded rather than counted as a fix: the port
carries the clock of the existing date through a day-selection
(`date_row.rb:136-146`) where upstream stores midnight (`DateRow.vala:47`),
and step 23 asserts it. It belongs in `FINDINGS.md` as an upstream proposal.

## Unit: keyword list — `src/KeywordList.vala` + `.ui` → `keyword_list.rb`

Group title, header-suffix add button (`.flat`, `list-add-symbolic`, tooltip,
`keyword-list.add-keyword`), `.boxed-list` list box, `row-activated`,
`<Control>Return`, the action group, the whole empty state
(`AdwPreferencesRow` → `GtkCenterBox` → icon halign END hexpand margin-end 12
+ *Add Keyword*), and both focus rules.
**Driven**: steps 28–39 — load two keywords, add, type, delete the middle one
and check the neighbours survived, empty the list and see the empty state
return, activate it, and reach the same action by `<Control>Return`.
`tmp/shots/07-keywords.png`, `08-keywords-empty.png`. parity
The add button's `visible` is recomputed in `settle` instead of bound to an
`is-empty` property — a correspondence with the same result, asserted at
step 36.

## Unit: keyword row — `src/KeywordRow.vala` → `keyword_row.rb`

`AdwEntryRow`, focusable, title *Keyword*, `cross-symbolic` prefix button with
`.flat` and *Delete Keyword*. Deletion is by row identity rather than by text
— strictly better than upstream, which removes the first match and can delete
the wrong duplicate — and step 32 asserts the index, not the text. parity

## Unit: drop overlay — `src/DropOverlay.vala` → `drop_overlay.rb`

Bin → overlay + overlaid revealer, `can_target = false`, `visible = false`,
CROSSFADE, `notify::current-drop`, `.overlay-drag-area` on the overlaid
widget. **Driven**: steps 45–49 start a drag, assert the revealer and the
class, end the drag and assert both are gone.
`tmp/shots/09-drag-tint.png`. parity

## Unit: password dialog — `src/PasswordDialog.vala` + `.ui` → `password_dialog.rb`

350×320, title, `show-title = false` header, `.compact` status page with
`key-symbolic` and the basename description, `.boxed-list` list box,
`AdwPasswordEntryRow`, `.pill .suggested-action` Decrypt, the `dialog` action
group, the capture-phase Return/Escape controller, and `closed` → cancel with
the once-only guard standing in for `requires (task.status == RUNNING)`.
**Driven**: steps 60–71 — a real AES-128 PDF, a wrong password refused into a
toast, a cancel that opens nothing, and the right password opening the
document. `tmp/shots/13-password.png`, `14-password-refused.png`,
`15-decrypted.png`. parity

## Unit: save-changes dialog — `SaveChangesDialog.vala` + `.ui` → `save_changes_dialog.rb` + `document_row.rb`

Heading, body, three responses with destructive/suggested appearances,
default `save`, close `cancel`, the scrolled `.boxed-list` list box, and
`DocumentRow` with its valign-center check button checked by default and
`document.title` as the row title. `AdwMessageDialog` → `AdwAlertDialog` is
libadwaita's own 1.6 replacement.
**Driven**: steps 72–84 — an unsaved edit, `win.open` raising the dialog
instead of a chooser, cancelling and losing nothing, then a close answered
with Save that writes the file and lets the close through. The harness clicks
the `GtkButton` AdwAlertDialog built for the response, because
`adw_alert_dialog_response()` is not bound.
`tmp/shots/16-save-changes.png`, `18-closing.png`. parity

## Unit: shortcuts — `src/gtk/shortcut-window.ui` → `shortcuts_dialog.rb`

Two groups, all eight shortcuts, all ten strings with
`msgctxt "shortcut window"`. `GtkShortcutsWindow` (deprecated in GTK 4.18) →
`Adwaita::ShortcutsDialog`, with upstream's two `GtkShortcutsGroup`s as two
`Adwaita::ShortcutsSection`s since Adwaita has no group inside a section.
**Driven**: steps 8–9 open it and count the sections and the eight shortcuts.
`tmp/shots/03-shortcuts.png` shows both headings and the accelerator chips.
parity

Residual, recorded and not counted as a gap: upstream's `max-height = 10` on
the section has no Adwaita counterpart, and the port asserts the dialog
paginates itself. Neither side can reach ten rows — the longest group has
four — so the behaviour is unobservable on both. Last round's accountability
finding on this sentence is downgraded accordingly; the dialog has now at
least been opened.

## Unit: stylesheet — `src/style.css` → `style.rb`

All three rules byte-identical, loaded at `PRIORITY_APPLICATION`.
**Driven**: step 2 asserts the provider is on the display.
`.document-view-drop` is applied by both sides and defined by neither — an
upstream bug the port reproduces rather than silently fixes, reported
upstream. parity

---

## Gap 1 — the port carries no licence text

- Upstream: `COPYING` at the root, the full GPL-3.
- Port: no `COPYING`, no `LICENSE`. `paper-clip-rb.gemspec:18` declares
  `spec.licenses = ["GPL-3.0-or-later"]` and the file it names is not there.
- Cost: anyone who clones, forks or packages the port receives a GPL work
  with no licence in it. Downstream packagers (Debian, Fedora, Flathub, the
  gem index) all require the text, not the identifier, and the gemspec's
  claim is unverifiable from the tree.
- Remedy: copy upstream's `COPYING`. One file, no code.

## Gap 2 — the About dialog's debug block cannot name an XMP stack

- Upstream: `src/application.vala:196-215` prints `Poppler <version> (Compile
  Time)` **and** `Exempi <version>`.
- Port: `about_dialog.rb:67` now prints a real runtime Poppler version — this
  half is closed. Line 68 prints `Exempi: not linked — this port edits the XMP
  packet as XML`, which names no version of anything.
- Cost: a maintainer reading a bug report pasted out of this dialog cannot
  tell which XMP code produced the behaviour. The port *has* an XMP stack —
  `lib/paper_clip/xmp_packet.rb` — and it has a version, the gem's.
- Remedy: print the port's own revision in Exempi's place. One line.

## Gap 3 — the thumbnail's whole reason for existing is unexercised

Two halves of one gap, both in what the 278 checks do not reach.

**The PNG-cache branch is unreachable from the repository.**
`Thumbnailer#load_scaled` fires when `width × height ≥ max_size² × 2.5`, which
is `350² × 2.5 = 306,250`. Every fixture page in `spec/` and `test/` is
`MediaBox [0 0 200 200]` — area 40,000. Nothing in `test/`, `spec/` or
`lib/` so much as names the `thumbnails` cache directory outside
`thumbnailer.rb:53`. So `write_to_png`, the seven-step scale loop,
`from_file_at_size`, `ExportError` and `CacheError` are, today, dead code as
far as anything executable in this repository is concerned.

**The rendering path is only ever exercised on a blank page.** The fixture
builder emits a page with no `/Contents`. Step 15 asserts the paintable is not
nil. A `Poppler::Page#render` that drew nothing, a white rectangle that
covered the texture instead of backing it, a filter constant the bindings
reject — none of those would fail a check, and `tmp/shots/05-editor.png` would
look exactly as it does.

- Cost: the preview exists so a user can see *which* PDF they opened before
  overwriting its metadata. The port can demonstrate that a paintable arrives.
  It cannot yet demonstrate that the paintable shows the page.
- Remedy: one fixture with a `/Contents` stream drawing something
  recognisable, and one fixture with a `MediaBox` over ~554×554 so the cache
  branch runs. Two fixtures, four checks, one screenshot to read.

## Rules observed

- No unit was marked at parity on the strength of the scan. Every one was read
  on both sides and then driven.
- Platform classes (`flat`, `osd`, `pill`, `boxed-list`, `title-1`,
  `dim-label`, `property`, `compact`, `suggested-action`, `linked`,
  `icon-dropshadow`) were not reported as missing stylesheet rules.
- Where a facet is read rather than observed, the row says so. "parity by
  reading" and "parity. Driven" are different verdicts and are written
  differently.
- The three gaps are gaps. None is lowered to a note, and none is excused by
  a binding limitation.
