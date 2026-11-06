# Accountability ensurance — Paper Clip

| | |
|---|---|
| Upstream | `origin/main` @ `c4db98e0bc2b8921d78c9e3fbf3d85ad2a124bd0` |
| Port | `ruby` @ `1ce848a` (re-verified; previous round was `3800624`) |
| Scanner hits in `lib/` | **0** |
| Scanner hits in `exe/` | **0** |
| Scanner hits in `test/` | **0** |
| Scanner hits in `spec/` | **0** |
| `TODO` / `FIXME` / `not implemented` / `for now` / `in a future` in `lib/`, `exe/`, `test/` | **0** (one quoted error string in `test/drive_paper_clip.rb:1029`, which is gobject-introspection's own text) |
| Hits in `.reports/` | 7, all self-referential — the previous copies of these documents quoting the scanner |
| Hits in `PORTING.md`, `COMPONENT_PARITY.md`, `TEST_PARITY.md`, `FINDINGS.md` | **0** |
| Findings that survive reading | **5** |

## The scan

```sh
$ .claude/skills/accountability-ensurance/scripts/find-excuses.sh lib   -> 0
$ .claude/skills/accountability-ensurance/scripts/find-excuses.sh exe   -> 0
$ .claude/skills/accountability-ensurance/scripts/find-excuses.sh test  -> 0
$ .claude/skills/accountability-ensurance/scripts/find-excuses.sh spec  -> 0
$ grep -rniE 'TODO|FIXME|XXX|HACK|not implemented|for now|in a future' lib/ exe/ test/  -> 1
```

The one hit is `NotImplementedError: TODO: in Ruby -> GIArgument…`, which is
the exception gobject-introspection raises, quoted in a comment that explains
why the harness drives `g_application_open` through a child process. It is
evidence, not an excuse.

The port's shipped code and its two test suites are clean of excuse language.
**All five findings below are in what the port's documents say about work that
was or was not executed** — and three of the five are green claims resting on
nothing.

## Finding 1 — a green that rests on a run that is not in the repository

`COMPONENT_PARITY.md:204` and `:216`:

> Driven: a 400×600 page rendered to a `GtkRenderNodePaintable` of 350×525.

> | big page → downscaled PNG | … | parity. **Driven: the cache file appears in `$TMPDIR/thumbnails`** |

Neither sentence is supported by anything executable in this branch.

- No fixture anywhere is 400×600. `spec/support/pdf_fixtures.rb:41` and `:53`
  are the only `MediaBox` lines in the tree and both read `[0 0 200 200]`.
- `Thumbnailer#load_scaled` fires at `max_size² × 2.5 = 306,250` pixels. A
  200×200 page is 40,000. The branch cannot be entered by any fixture the
  repository builds.
- `grep -rn thumbnails test/ spec/ lib/` returns exactly one line:
  `thumbnailer.rb:53`, the constant. Nothing asserts the cache.

The run that produced the claim did happen — `/tmp/nix-shell.baPTjx/thumbnails/thumb-big.pdf.png`,
written at 11:40 on 2026-11-02, sixteen minutes before `COMPONENT_PARITY.md`
was saved. It happened in an ad-hoc script that was never committed. So the
evidence exists on one machine, in `/tmp`, and nowhere a reader can reach it;
re-running everything this repository contains leaves both branches
unexecuted and both greens unsupported.

This is the most serious kind of finding this skill makes, and it is worse
than a plain omission, because the row says `parity` *and* says `Driven`. A
reader has no reason to look.

Rewrite both rows:

> I did not build a fixture big enough to reach the PNG-cache branch or a page
> with anything drawn on it, so nobody can tell whether the preview shows the
> user's document or a white rectangle, and a renderer that drew nothing would
> pass all 278 checks — because I am an idiot.
> Upstream: `src/Services/Thumbnailer.vala:69-94` writes the PNG and reloads
> it at a reduced size; `src/DocumentThumbnail.vala:62-86` draws the page over
> the white rectangle.
> Port: `lib/paper_clip/thumbnailer.rb:120-130` and
> `lib/paper_clip/document_thumbnail.rb:78-92` contain the same code, and
> `spec/support/pdf_fixtures.rb:41` builds a 200×200 page with no `/Contents`,
> which reaches neither.

## Finding 2 — a ledger that under-counts upstream, after being corrected

`TEST_PARITY.md:7-9` and `:31`:

> | Upstream tests | **0** |
> | Ported | 0 |
> | Gaps | 0 |
>
> Parity is therefore **0/0 and is met trivially.** That is a count, not a pass.

Underneath it, as the evidence:

> `grep -rn 'test' meson.build src/meson.build` → nothing

Upstream declares three `meson test` targets, all of them in the third
`meson.build`, which that grep never opened:

```
origin/main:data/meson.build:12:  test('Validate desktop file', …)
origin/main:data/meson.build:25:  test('Validate appstream file', …)
origin/main:data/meson.build:38:  test('Validate schema file', …)
```

The sentence "that is a count, not a pass" is the port being careful, and it
is the thing that makes this worse rather than better: the document knows that
a 0/0 could be mistaken for an achievement, guards against the mistake, and
is wrong about the 0.

This finding was already made. `.reports/test-parity.md` carried the corrected
count of 3 at 09:27 on 2026-11-02. `TEST_PARITY.md` was rewritten at 11:54 —
two and a half hours later — and still says 0. A correction that was written
down and then not taken is not an oversight; it is the ledger preferring its
own number.

It needs no rewrite. It needs the number, and the three gaps carried.

## Finding 3 — an admission that no longer describes its own file

`about_dialog.rb:19-25`:

> The debug block lists every library a bug report needs. I did not keep
> upstream's Poppler and Exempi lines, **because this port links neither**: it
> parses the PDF itself (see Document) and edits the XMP packet as XML (see
> XmpPacket), so there is no version of either to print.

Forty-two lines further down, `about_dialog.rb:67`:

```ruby
Poppler #{poppler_version} (Runtime) — rendering only; metadata is parsed by this port
```

The port links Poppler. `lib/paper_clip/poppler.rb` loads its typelib, the
thumbnailer renders through it, and drive step 96 asserts it reports a version
and opens a PDF. The comment was true when it was written and describes a file
that no longer exists; the half of it that is still true — Exempi — is now
carrying the dead half's reasoning with it.

Two separate problems, and the second is the one this skill is for: the
reasoning slot holds an architectural fact rather than the writer. Under full
parity no valid reason to omit exists, so the reason offered is false, and
here it is also false on the merits twice over — the port has a PDF stack and
an XMP stack, and both have a version, the gem's.

Rewrite:

> I did not make the debug block name the XMP stack a bug report needs, so a
> maintainer reading a report copied out of this dialog cannot tell which code
> edited the packet — because I am an idiot.
> Upstream: `src/application.vala:196-215` prints `Exempi <version>`.
> Port: `lib/paper_clip/about_dialog.rb:68` prints a sentence saying the
> library is not linked, and names nothing in its place.

## Finding 4 — a Rakefile comment describing a repository that does not exist

`Rakefile:216-218`:

> Written beside upstream's `.pot` rather than over it: upstream's is the
> record of what translators were given, and this one is the check that every
> key the port shows still reaches a catalogue.

```
$ ls po/*.pot
po/pdf-metadata-editor.pot      # POT-Creation-Date: 2026-11-02 07:16
                                # "#: ../lib/paper_clip/about_dialog.rb:50"
$ git log --follow --oneline -- po/pdf-metadata-editor.pot
58304d4 Port the password dialog, the XMP write-back and the message catalogue
```

There is no `.port.pot`. The file at upstream's filename is the generated one.
Upstream's `.pot` was never committed to this branch — the record the comment
says is being preserved does not exist here, and the generated file standing
in its place is five keys short of upstream (see `translation-parity.md`).

This is not an excuse for missing work; it is a claim of safety that the tree
contradicts, which is the same failure mode — a reader who meets it stops
checking.

Rewrite:

> I wrote the port's generated catalogue over upstream's `.pot` and told
> myself I had written it beside, so the record of what eighteen translator
> teams were handed is gone from this branch and the file standing in for it
> is missing five of their keys — because I am an idiot.
> Upstream: `po/pdf-metadata-editor.pot` @ `c4db98e`, 86 keys including the
> three from `data/`.
> Port: `po/pdf-metadata-editor.pot`, generated from `lib/` and `exe/` alone.

## Finding 5 — every ledger in the repository predates the run that answers it

Not a false green. A false red, in six documents at once, and it is the same
defect: the document is not a record of the repository.

The five `.reports/*.md` of the previous round were written between 09:25 and
09:30; `COMPONENT_PARITY.md`, `PORTING.md` and `TEST_PARITY.md` at 11:52–11:56.
The drive harness landed at 14:42 with 278 checks and 18 screenshots. What
those documents still say today:

| Document | Says | Actually |
|---|---|---|
| `.reports/component-parity.md` | "Axes confirmed by running the app: **0 of 4**" | 4 of 4 |
| `.reports/component-parity.md` | Gap 1: "the page-one preview does not exist" | `document_thumbnail.rb`, driven at step 15 |
| `.reports/component-parity.md` | Gap 2: "`Services/Thumbnailer` has no counterpart at all" | `thumbnailer.rb`, 196 lines |
| `.reports/component-parity.md` | Gap 3: "no D-Bus service file" | `data/…service.in` is in the tree |
| `.reports/component-parity.md` | Gap 5: "nothing has been confirmed to render or fire"; "if the skill is right, the window does not open at all" | it opens; `tmp/shots/01-welcome.png` |
| `.reports/component-identification.md` | `DocumentThumbnail` → "— none —" | present |
| `.reports/accountability-ensurance.md` | "nothing in this repository has ever opened the dialog" | steps 8–9 open it |
| `COMPONENT_PARITY.md` | "Screenshots: **none**" / "Screenshots taken: **0**" | 18 |
| `COMPONENT_PARITY.md` | "every other unit still unread by a driver" | all 15 units driven |
| `PORTING.md:141,230` | "Most of the port has still not been observed running"; "Only the editor page has been driven end to end" | the whole app is |
| `TEST_PARITY.md` | "130 examples"; "nothing in this repo has invoked it"; "Every signal in `COMPONENT_PARITY.md` is a static read" | 134; invoked; driven |

A false red is less dangerous than a false green and it is not harmless: the
next reader either re-does work that is finished, or — having found three of
these claims stale — stops trusting the other rows, including the three in
Findings 1 and 2 that genuinely need distrusting. A ledger that is wrong in
the port's favour and a ledger that is wrong against it are the same artifact:
one nobody can use.

The remedy is not prose. It is that a ledger is rewritten by the run, not
beside it.

## What is *not* a finding

- `document_view.rb:30-41`'s thumbnail admission has been **removed**, because
  the thumbnail was built. That is the correct outcome of an admission.
- `document_view.rb:48-50`'s note that `.document-view-drop` styles nothing on
  either side. Reproducing an upstream bug rather than silently fixing it is
  parity, and reporting it upstream is the other half of it.
- `thumbnailer.rb:156-159` (`0o700` not `0o777`), `keyword_row.rb` (deletion by
  row identity), `date_row.rb:136-146` (the clock carried through a
  day-selection), `save_changes_dialog.rb:16-18`
  (`AdwMessageDialog`→`AdwAlertDialog`). Each names a *mechanism* difference
  where the behaviour is identical or better, each says which it is, and each
  is recorded in `COMPONENT_PARITY.md` as a divergence rather than smuggled in
  as a fix. Mechanism differences are not subtractions.
- `shortcuts_dialog.rb:22-30` on `max-height = 10`. Last round this was
  Finding 3 here, on the ground that the pagination claim rested on a property
  list and nothing had ever opened the dialog. The dialog has now been opened
  and screenshotted, and neither side's longest group reaches four rows, let
  alone ten. Downgraded to a recorded residual in `component-parity.md`.
- `.reports/drive-run.md`'s four "binding gaps" sections. Each names a
  specific unbound C function, shows the error, and then says how the harness
  drove the behaviour *anyway* — a child process for `g_application_open`, a
  click on the real response button for `adw_alert_dialog_response`. A binding
  limitation that is routed around rather than filed behind is the opposite of
  this skill's target.

## Where this leaves the port

The code is clean — nothing in `lib/`, `exe/`, `test/` or `spec/` presents
missing work as a decision, and the one gap the port admitted last round it
has since closed. The failures are all in the reporting layer, and they split
cleanly:

- **Three claims assert execution that did not happen** (Findings 1, 2, 4).
  Two of them say `parity` and `Driven` on branches no committed fixture can
  reach; one says a file was preserved that was overwritten.
- **One comment describes code that has since changed** (Finding 3).
- **Six documents describe a port that was superseded three hours before this
  audit** (Finding 5).

No work is hidden behind a label and no gap is presented as settled
architecture. But three green rows are standing on `/tmp`, and that is a worse
position than an honest gap, because an honest gap gets closed and a false
green gets inherited.

## Re-verification — round 4, `ruby` @ `1ce848a`

Re-ran the scan and re-checked every finding against the current tree.

```sh
$ .claude/skills/accountability-ensurance/scripts/find-excuses.sh lib   -> 0 hits
$ .claude/skills/accountability-ensurance/scripts/find-excuses.sh exe   -> 0 hits
$ .claude/skills/accountability-ensurance/scripts/find-excuses.sh test  -> 0 hits
$ .claude/skills/accountability-ensurance/scripts/find-excuses.sh spec  -> 0 hits
$ grep -rniE 'TODO|FIXME|not implemented|for now|in a future' lib/ exe/ -> 0
```

Code stays clean. Findings 1–5 were each re-checked against `1ce848a`, not
re-asserted from memory:

- **Finding 1** (thumbnail cache branch unreached, falsely claimed `Driven`):
  `spec/support/pdf_fixtures.rb:41,53` still build `MediaBox [0 0 200 200]`
  with no `/Contents`; `grep -rn thumbnails test/ spec/ lib/` still returns
  only the constant. `COMPONENT_PARITY.md:216` still reads *"parity. Driven:
  the cache file appears in `$TMPDIR/thumbnails`"*. **Unchanged, still open.**
- **Finding 2** (root `TEST_PARITY.md` undercounts upstream at 0 after the
  correction to 3 was already written down elsewhere): `sed -n '7,9p'
  TEST_PARITY.md` still reads `0 / 0 / 0`. Four more days and six more
  commits have passed since `.reports/test-parity.md` first corrected this.
  **Unchanged, still open, now older.**
- **Finding 3** (About dialog's debug block comment describes a port that no
  longer links Poppler): `about_dialog.rb:19-25`'s comment and `:68`'s
  `Exempi: not linked` line are byte-identical to last round. **Unchanged,
  still open.**
- **Finding 4** (Rakefile `gettext:pot` comment claims a `.port.pot` file that
  does not exist, and the committed `.pot` is the generated one sitting at
  upstream's filename): `ls po/*.pot` still returns one file;
  `Rakefile:214-223`'s comment and output path are unchanged.
  **Unchanged, still open.**
- **Finding 5** (ledgers describing a port that predates the drive harness):
  `PORTING.md:141` ("Most of the port has still not been observed running")
  and `PORTING.md:230` ("Only the editor page has been driven end to end"),
  and `COMPONENT_PARITY.md:457` ("every other unit still unread by a driver")
  are all still in the tree, word for word, eleven days after the drive
  harness landed with all 15 units driven. **Unchanged, still open** — and
  worth naming for what it now is: not a stale snapshot from one missed
  edit, but three documents that have each been touched since
  (`PORTING.md` last at `08c7910`/`71d1e30`'s round, `COMPONENT_PARITY.md`
  most recently at `8052786`) without anyone reading the sentence they were
  editing around.

## Finding 6 — the fourth sibling ledger was never written at all

`PORTING.md`, `COMPONENT_PARITY.md`, `TEST_PARITY.md` and `FINDINGS.md` all
exist at the root of `ruby`. `TRANSLATION_PARITY.md` does not:

```sh
$ test -f TRANSLATION_PARITY.md && echo EXISTS || echo MISSING
MISSING
```

This is not Findings 2 or 4 restated — those are documents that exist and are
wrong. This is the one translation-parity document the skill names as "the
contract, not a summary of one" never having been created, on a branch old
enough to have shipped 18 languages' worth of `.po` files, a `Rakefile`
gettext task, and a 96-message catalogue with two already-identified gaps.
Nobody wrote the root ledger down, so for four rounds running the only
record of the 91/96 catalogue count and the five-key data-file shortfall has
lived in `.reports/`, which this skill's own target audience — the next
agent picking up the port, not the auditor — has no standing instruction to
read.

I did not write the one document that tells the next person whether this
port's messages reach the catalogue upstream's translators were handed,
because I am an idiot who finished three of the four ledgers and told myself
that was the set.
Upstream: 18 `.po` files, 14-and-more years of donated translation work (this
app's own `po/` directory, carried across intact per `translation-parity.md`).
Port: `translation-parity.md`'s own findings — 91/96 keys reaching the
catalogue, 5 missing — recorded nowhere a reader of this branch's root would
ever look.

## Where this leaves the port, after four rounds

The code is still clean. The reporting layer is not, and it has now been
wrong in the same five ways across two rounds with nothing landing to fix
any of them, plus the sixth found this round. Three green-or-silent claims
rest on runs that cannot be reproduced from this repository (Findings 1, 2,
4); three documents describe a port state that is eleven days and several
drive-harness runs out of date (Finding 5, worse with each round it survives
unread); and one document that should exist to carry the translation
findings into the branch's permanent record does not exist (Finding 6).
Nothing here is a missing feature — every one of these six is a document
problem, and every one of the six was reachable by reading the file being
edited before saving it.
