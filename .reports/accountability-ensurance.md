# Accountability ensurance — Paper Clip

| | |
|---|---|
| Upstream | `origin/main` @ `c4db98e0bc2b8921d78c9e3fbf3d85ad2a124bd0` |
| Port | `ruby` branch, this audit |
| Scanner hits in `lib/` | **0** |
| Scanner hits in `exe/` | **0** |
| Scanner hits in `spec/` | **0** |
| `TODO` / `FIXME` / `XXX` / `HACK` in `lib/` or `exe/` | **0** |
| Hits elsewhere in the tree | **18** (17 in the previous `.reports/`, 1 in `TEST_PARITY.md`) |
| Findings that survive reading | **4** |

## The scan

```sh
$ .claude/skills/accountability-ensurance/scripts/find-excuses.sh lib    -> 0 hits
$ .claude/skills/accountability-ensurance/scripts/find-excuses.sh exe    -> 0 hits
$ .claude/skills/accountability-ensurance/scripts/find-excuses.sh spec   -> 0 hits
$ grep -rniE 'TODO|FIXME|XXX|HACK|not implemented|unimplemented|stub' lib/ exe/   -> 0
```

Every `for now`, `later`, `skip` and `placeholder` the broad grep turns up in
`lib/` is load-bearing prose or a method name — `skip_eol`, `skip_space`,
`skip_unknown` in the PDF tokeniser, `later definitions win` describing an
incremental update, `missing-image placeholders` describing what GTK draws
without an icon path. Read, not assumed. None of them stands in for work.

The port's shipped code is clean. The findings below are in what the code
*says about its gaps*.

## Finding 1 — the thumbnail admission is correct, and it is the only one that is

`lib/paper_clip/document_view.rb:30-41` is in the required form:

> I did not build the page-one preview, so a user cannot see which PDF they
> opened before they start editing its metadata, and a transparent or
> mis-selected document looks exactly like the right one — **because I am too
> stupid to have built it.**
> Upstream: `src/gtk/document-view.ui:25` … `src/DocumentThumbnail.vala` …
> Port: `lib/paper_clip/document_view.rb` appends the title label straight
> into the box …

First person, admission first, cost to the user named, both sides cited, the
reasoning slot holding nothing but the writer. This is what the other three
should look like. Not a finding — the reference.

## Finding 2 — `about_dialog.rb:18-21` offers a reason that is not the writer

> The debug block lists every library a bug report needs. **I did not keep
> upstream's Poppler and Exempi lines, because this port links neither**: it
> parses the PDF itself (see Document) and edits the XMP packet as XML (see
> XmpPacket), so there is no version of either to print.

The admission is there and the citation is there, and then the reasoning slot
is filled with an architectural fact. Under full parity no valid reason to
omit exists, so the reason offered is false and offering it is the finding —
and here it is also *wrong on the merits*, which is what makes it worth
rewriting rather than re-labelling. The port does have a PDF stack and an XMP
stack; they are `lib/paper_clip/document.rb` and
`lib/paper_clip/xmp_packet.rb`, and they have a version — the gem's. The
behaviour upstream ships is "the About dialog tells a maintainer which PDF
stack produced the bug", and the port can ship it.

Rewrite:

> I did not make the debug block name the PDF and XMP stacks a bug report
> needs, so a maintainer reading a report copied out of this dialog cannot
> tell which code parsed the file — because I am an idiot.
> Upstream: `src/application.vala:196-215` prints `Poppler <version>` and
> `Exempi <version>`.
> Port: `lib/paper_clip/about_dialog.rb:66-67` prints two sentences saying
> neither library is linked, and names nothing in their place.

## Finding 3 — `shortcuts_dialog.rb:22-29` files two omissions as properties

> Two rows of upstream's `.ui` have no counterpart here, and both are
> **properties of the widget rather than content** …
> `max-height = 10` … is a GtkShortcutsSection property. Adw.ShortcutsSection
> has only item-type, n-items and title — **the dialog sizes and paginates
> itself — so there is nothing to set.**

"No counterpart" is the construction the skill names explicitly: the
counterpart is the *behaviour*, and the behaviour always has one. Here the
behaviour is "a section longer than ten rows paginates instead of growing the
dialog", and the sentence asserts Adwaita already does it. That assertion may
well be true — but it was never observed, because nothing in this repository
has ever opened the dialog (see `component-parity.md` Gap 5), and a claim
about pagination that rests on a property list is a reading, not a result.
The second half — the dialog's own title coming from libadwaita's catalogue —
is a genuine correspondence and needs no rewrite.

Rewrite the first half:

> I did not confirm that a section of more than ten shortcuts paginates rather
> than growing the dialog off the screen, so I do not know whether a user on a
> small display can reach the last shortcut — because I am an idiot.
> Upstream: `src/gtk/shortcut-window.ui:8` sets `max-height = 10` on the
> section.
> Port: `lib/paper_clip/shortcuts_dialog.rb:40-68` sets nothing, on the
> strength of Adw.ShortcutsSection's property list and no observation.

## Finding 4 — `document.rb:19-27` makes the environment the premise of a file

> **I could not load Poppler through gobject-introspection** the way the
> adwaita gem loads its own typelib: there is no `Poppler-0.18.typelib`
> anywhere on this system and no `poppler` gem in the bundle … **libexempi has
> no Ruby binding either**, so the XMP packet is edited as the XML it is.

This is the environment named as the premise a whole file rests on. It differs
from the usual instance of that failure in one important way: the file does
not *stop* at the premise — `document.rb` goes on to parse and write the PDF
itself, `pdf_crypt.rb` implements the standard security handler, and
`xmp_packet.rb` edits the packet. about 1,980 lines of answered work, with 130 green
specs over it. The admission is honest and the work was done.

What the premise still covers is the one thing that was *not* answered: the
page accessor. `src/Document.vala:287-289` exposes `get_page_for_index`, the
port exposes nothing, and that absence is what makes Gap 1 unclosable rather
than merely unclosed. The comment lets "no Poppler" stand for it, which is an
environment fact standing in for a missing method.

Rewrite the last clause:

> I did not build a page accessor, so nothing in this port can render or even
> measure a page and the editor has no preview to show — because I am an idiot.
> Upstream: `src/Document.vala:287-289` returns a `Poppler.Page` for an index.
> Port: `lib/paper_clip/document.rb` parses the page tree far enough to count
> pages (`:249`) and no further.

## Finding 5 — `TEST_PARITY.md:109` claims a row was not marked `n/a` while the ledger it belongs to is wrong

```
TEST_PARITY.md:109:n/a:asserts the behaviour cannot exist here …
```

The line is "No row was lowered, merged or marked `n/a`" — a rules-observed
footer, and the scanner's hit on it is a false positive on the word itself.
The real accountability problem in that document is not the word: it is that
the document reports **0 upstream tests** on the strength of a grep that
checked two of the three `meson.build` files, and three declared upstream
tests are consequently invisible rather than owed. See `test-parity.md`.

A ledger that under-counts upstream is the most effective excuse in the
repository, because it does not read as one. It needs no rewrite — it needs
the number corrected and the three gaps carried.

## What is *not* a finding

- `FINDINGS.md` §1–§10. All ten are first-person, name the cost, cite both
  sides and give an estimated cost of closing. §8 in particular —
  "Nothing has been driven or screenshotted — owed, and blocked here" —
  states plainly that every widget verdict is a static reading and that a
  handler wired to an empty method would pass it. That is the admission this
  skill exists to produce, and the port wrote it unprompted.
- `document_view.rb:58-62`'s note on `.document-view-drop` styling nothing.
  Reproducing an upstream bug rather than silently fixing it is parity, and
  reporting it upstream is the right half of it.
- `document_manager.rb:11-17`, `keyword_row.rb:9-18`,
  `date_row.rb:21-27`, `password_dialog.rb:13-21` — each explains a
  *mechanism* difference (observer list vs GObject notify, row identity vs
  text match, callbacks vs coroutines) where the behaviour is identical or
  better. Mechanism differences are not subtractions.

## Where this leaves the port

Four comments to rewrite, one ledger number to correct. No work is hidden
behind a label, no gap is presented as a decision, and the largest gap in the
port is admitted in the skill's own words by the person who left it. That is
a good position. It is not a clean one: Findings 2–4 each put a reason in the
slot reserved for the writer, and each reason is doing the job of making an
absence sound settled.
