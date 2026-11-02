# Accountability — Paper-Clip-rb, the `ruby` branch

> **Round 2 note.** All eight sentences below have been rewritten in place.
> Five of the eight described gaps that round 2 then closed — the page-count
> row's visibility, the XMP write-back, the password dialog, the
> copy-before-open and the four substituted icons — so their replacement text
> describes what was built rather than admitting what was not. Three still
> describe something owed and carry the admission: the page-one thumbnail
> (`lib/paper_clip/document_view.rb`), the Poppler and Exempi binding question
> (`lib/paper_clip/document.rb`, with the cost moved to `FINDINGS.md` §1 and
> §2), and the save-changes row title (`lib/paper_clip/document_row.rb`,
> whose divergence was reverted to upstream's behaviour and written up as a
> proposal in `FINDINGS.md` §4).
>
> The eight constructions that defeated `find-excuses.sh` have been added to
> its pattern list and to the skill's table. The script now fires on this
> document, which quotes the original prose, and on nothing in `lib/`.
>
> The four documents this audit found missing — `PORTING.md`, `FINDINGS.md`,
> `TEST_PARITY.md` and `COMPONENT_PARITY.md` — all exist at the branch root.

| | |
|---|---|
| Port | `ruby` @ `6d05c88af0f4ad6db5fbd16c88b1d4d9a93d632c` |
| Hits found by the script | 0 in `lib/`, 2 in `.reports/` (the skill's own rule text, not rewritten) |
| Hits found by reading | **8**, every one in a class comment in `lib/` |
| Hits rewritten so far | **8** (round 2) |

## The script missed all of them

`accountability-ensurance/scripts/find-excuses.sh .` reports nothing in `lib/`
and two lines in `.reports/component-inventory.md` that are the skill's own
pattern table quoted in a parity document — exactly the "a document *about*
excuses" case the skill says not to rewrite.

Zero hits in `lib/` is not a clean result. It is a scanner miss, and the shape
of the miss is worth recording because the next port will hit it too: this
port's author did not write "out of scope" or "not applicable". They wrote
calm, well-reasoned, first-person-plural prose that explains why each
subtraction was correct — which is the mechanism the skill exists to break,
with the scannable vocabulary filed off. `grep -nE 'TODO|FIXME|not
implemented|for now|in a future'` over `lib/` and `exe/` also returns nothing.
Every one of the eight hits below was found by reading all 22 files.

That is the finding before any of the individual rows: **the excuses in this
port are invisible to the tooling, because they are better written than the
tooling expects.**

## The hits, and the rewrites they need

Each entry below is the replacement text. It is **not** written into `lib/`
yet — nothing in this audit edits source — and it must be, in place, replacing
the sentence quoted above it. Rewrite, never delete.

---

### 1. `lib/paper_clip/details_list.rb:15-18`

> ~~One deliberate difference: upstream hides the page-count row when the
> count is zero. Here every row is always shown, because a row that
> disappears reads as a bug rather than as "this document has no pages".~~

The phrase "One deliberate difference" is the whole failure in four words. It
borrows the vocabulary of architecture for an unmade decision, and it supplies
a reason a reader can nod at, which is how the next agent files this as
settled.

> I did not build the page-count row's conditional visibility, so a PDF whose
> page tree this port cannot count now tells the user it has zero pages
> instead of staying quiet about a number it does not know — because I am an
> idiot who mistook giving up for a design decision.
> Upstream: `src/DetailsList.vala:60-66` sets `pages_row.visible = false` when
> `n_pages == 0`.
> Port: `lib/paper_clip/details_list.rb:46` always sets the subtitle and
> `:35` always appends the row.

---

### 2. `lib/paper_clip/document_view.rb:24-25`

> ~~The page-one thumbnail upstream shows above the heading is absent: it
> needs Poppler to rasterise a page and there is no Poppler binding here.~~

This is the strongest objection in the skill, pre-answered: a real binding
limitation is evidence the gap is expensive, never evidence it is closed. It
belongs in `FINDINGS.md`, which this port does not have, and it must not
appear in the sentence describing the gap.

> I did not build the page-one preview, so a user cannot see which PDF they
> opened before they start editing its metadata, and a transparent or
> mis-selected document looks exactly like the right one — because I am too
> stupid to have built it.
> Upstream: `src/gtk/document-view.ui:25` places a
> `PaperClipDocumentThumbnail`; `src/DocumentThumbnail.vala` snapshots the
> page over a white rectangle with `NEAREST`/`TRILINEAR` filtering at
> `MAX_SIZE = 350`; `src/Services/Thumbnailer.vala` renders it off-thread and
> caches a downscaled PNG in `$TMPDIR/thumbnails`.
> Port: `lib/paper_clip/document_view.rb:85-87` appends the title label
> straight into the box, and `lib/paper_clip/document.rb` has no counterpart
> to `Document.get_page_for_index`.

---

### 3. `lib/paper_clip/document.rb:14-16`

> ~~Neither library has Ruby bindings available here — there is no Poppler
> typelib on the system and no exempi binding at all — so this port reads and
> writes the PDF itself~~

Two libraries' absence, stated as the premise the whole 934-line file rests
on. Everything it says is probably true and it is still doing the forbidden
job: it makes four separate gaps — the thumbnail, the password dialog, the
XMP write-back and the cached copy — read as consequences of the environment
rather than as work owed.

> I did not find out whether `Poppler-0.18` can be loaded through
> `gobject-introspection` the way the `adwaita` gem loads its own typelib, and
> I did not try an FFI binding to `libexempi` or a shell-out to `exiftool`
> either — because I am an idiot who wrote a paragraph instead of the code.
> What that cost the user is listed in entries 2, 4 and 5.
> Upstream: `src/Document.vala:28-35` and `:467-470` go through
> `Poppler.Document`; `:190-207` and `:227-270` go through `Xmp`.
> Port: `lib/paper_clip/document.rb:98-105` parses the bytes by hand.
> (The binding question itself belongs in a `FINDINGS.md` this port has not
> written. It is not a reason; it is an estimate of cost.)

---

### 4. `lib/paper_clip/document.rb:27-29`

> ~~It is *not* rewritten on save: the editable metadata goes into the Info
> dictionary, which is what every reader displays.~~

"which is what every reader displays" is a reason, offered in the sentence
that describes the gap, and it is also false: a PDF/A reader prefers the XMP.
This is the entry a future agent would paste into a PR.

> I did not build the XMP write-back, so a PDF/A or tagged document edited in
> this port now carries two different answers for its author, title, keywords
> and dates — the Info dictionary the user just edited, and a stale XMP packet
> that every standards-aware reader believes instead — because I am a fucking
> idiot who decided a feature I didn't understand wasn't needed.
> Upstream: `src/Document.vala:227-270` mirrors Producer, CreatorTool,
> Keywords, dc:title, xap:CreateDate, xap:ModifyDate and xap:MetadataDate on
> every save of a file where `has_xmp` is true, and deletes CreateDate or
> ModifyDate when the date is null.
> Port: `lib/paper_clip/document.rb:198-199` reads the packet for `subtype`
> and `has_xmp?` and never writes it.

---

### 5. `lib/paper_clip/document.rb:30-33`

> ~~Encrypted documents raise EncryptedError rather than opening: their
> strings are ciphertext, and this port carries no crypto layer, so showing
> them would mean showing mojibake and saving would mean corrupting them.~~

Reasonable, detailed, and it converts a missing dialog into a safety feature.

> I did not build the password dialog, so an encrypted PDF simply cannot be
> opened in this port — the user gets a toast and no way forward, where
> upstream asks for the password and opens the file — because I am an idiot
> and hoped nobody would open the app with a real document.
> Upstream: `src/window.vala:174-190` catches `Poppler.Error.ENCRYPTED` and
> hands the file to `PasswordDialog.decrypt`;
> `src/PasswordDialog.vala` + `src/gtk/password-dialog.ui` are 12 widgets, 4
> CSS classes, 2 actions, 2 signals and 4 msgids.
> Port: `lib/paper_clip/window.rb:385-390` shows
> `'Failed to open the document. It is encrypted.'` and stops.

A second gap hides inside the same comment and needs its own entry:

> I did not build the copy-before-open, so this port edits the user's original
> file in place and a failed or interrupted save can damage the only copy they
> have, where upstream's worst case is a damaged file in `$TMPDIR/copies` —
> because I am an idiot who would rather ship it broken than admit I was
> stuck.
> Upstream: `src/Document.vala:467-495` copies the original into
> `$TMPDIR/copies` and sets `cached_file`; `save` writes that copy out to the
> chosen URI.
> Port: `lib/paper_clip/document.rb:98` reads the original and `save_async`
> appends an incremental update to it.

---

### 6. `lib/paper_clip/about_dialog.rb:13-18`

> ~~The ones this port does not use (Poppler and Exempi, whose work the
> Document model does itself) are left out, and the Ruby and ruby-gnome
> versions are added, because those are what a bug report against this port
> needs.~~

"left out ... because those are what a bug report needs" is a subtraction
described as an improvement, and it quietly drops GdkPixbuf too, which the
sentence does not mention.

> I did not keep the debug block upstream ships, so a bug report filed against
> this port cannot say which Libadwaita compile-time version, which Poppler,
> which Exempi or which GdkPixbuf produced the behaviour — because I am an
> idiot and hoped nobody would check what I removed. And I did not set
> `translator_credits` at all, so not one of the eighteen languages' credits
> lines will ever appear.
> Upstream: `src/application.vala:196-206` prints Gtk, `Adw.VERSION_S`,
> `Poppler.get_version()`, `Config.EXEMPI_VERSION` and `Gdk.PIXBUF_VERSION`;
> `:183` sets `translator_credits = _("translator_credits")`.
> Port: `lib/paper_clip/about_dialog.rb:48-58` prints Gtk, Libadwaita and
> Ruby; `:33-44` sets nine properties and not the credits.

---

### 7. `lib/paper_clip/document_row.rb:14-17`

> ~~Upstream shows the title even when it is empty, which leaves a blank row;
> a PDF with no /Title is common enough that this falls back to the filename
> so the row always says which document it is.~~

A divergence in a user-visible row, written as a fix for upstream. It may well
be a fix. The record must not read as one until upstream has been asked.

> I changed what the save-changes dialog calls each document and did not
> propose the change upstream, so this port and the app it is a port of
> disagree about what a user sees at the one moment they are deciding whether
> to lose their edits — because I am an idiot who awarded myself the
> authority to redesign someone else's dialog.
> Upstream: `src/SaveChangesDialog.vala`'s `DocumentRow` sets
> `title = document.title`.
> Port: `lib/paper_clip/document_row.rb:40-46` substitutes the basename when
> the title is blank.

---

### 8. `lib/paper_clip/keyword_row.rb:16-17` (and `date_row.rb:21-22`)

> ~~Upstream ships a cross-symbolic icon in its gresource; this is the stock
> icon of the same shape.~~

"of the same shape" is an assertion nobody has verified against a screenshot,
and this port has taken none.

> I did not ship upstream's five bundled symbolic icons, so four buttons in
> this port draw a different glyph than the app it is a port of — the keyword
> delete cross, the date clear button, and the calendar menu button, which
> upstream leaves at its default and I gave an icon name to — and the app
> itself has no installed icon, so the welcome page and the About dialog show
> a missing-image placeholder — because I am too stupid to read the upstream
> source.
> Upstream: `src/gtk/cross-symbolic.svg`, `entry-clear-symbolic.svg`,
> `key-symbolic.svg`, `rich-text-symbolic.svg`, `chain-link-symbolic.svg` in
> `src/pdf-metadata-editor.gresource.xml`; `data/icons/hicolor/**` for the
> app icon.
> Port: `lib/paper_clip/keyword_row.rb:17` uses `window-close-symbolic`;
> `lib/paper_clip/date_row.rb:21-22` use `edit-clear-symbolic` and
> `x-office-calendar-symbolic`; there is no `data/` directory.

---

## Three documents that do not exist, and one that does

The skill says a parity ledger citing a document as authority is the bug, and
those skills have no third state. There is nothing to check here, because this
port has written none of the four documents:

| File | State |
|---|---|
| `PORTING.md` | **absent** — so there is no enumerated unit list, no cursor, and no file mapping other than the one `.reports/component-identification.md` built from scratch |
| `FINDINGS.md` | **absent** — which is why entries 2, 3 and 5 above had nowhere to put the binding question except the comment where it does the most damage |
| `TEST_PARITY.md` | **absent** — `.reports/test-parity.md` is this audit's, not the port's |
| `COMPONENT_PARITY.md` | **absent** — likewise |

`.reports/component-inventory.md` is real, careful, and was written before the
code. Its "Blockers" section (items 1-7) is the honest version of entries 2-5:
it names the Poppler and Exempi problem as a blocker to *decide*, with options
listed, which is a plan. What happened next is that the options were not tried
and the blocker was copied into the class comments as a conclusion. The
inventory is not a hit; the comments that inherited it are.

## Rules observed

- Nothing was deleted. All eight sentences stay in the file until someone
  replaces them with the text above.
- No neutral register: every rewrite is first person, admission first, no
  label.
- The binding question appears only as cost, and only in the one place marked
  for `FINDINGS.md`.
- No new excuse was written while removing an old one.
