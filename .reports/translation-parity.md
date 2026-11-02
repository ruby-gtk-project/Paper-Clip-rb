# Translation parity — Paper Clip

| | |
|---|---|
| Upstream | `origin/main` @ `c4db98e0bc2b8921d78c9e3fbf3d85ad2a124bd0` (2025-04-28) |
| Port | `ruby` @ `3800624` |
| Upstream keys (`msgctxt`, `msgid`) in source | **96** |
| Present in the port's source, byte-identical | **96** |
| Reworded, retyped or unmarked | **0** |
| **Present in the catalogue the port emits** | **91** |
| **Upstream keys the port's `.pot` loses** | **5** |
| Languages | 18 upstream, 18 in the port, `LINGUAS` and all 18 `.po` files byte-identical |
| Gaps | **2** |

Two different questions, and the port passes the first and fails the second.
Every string in the port's Ruby *says* what upstream said. The catalogue the
port *produces* is five keys short of upstream's, and the shortfall is
entirely in the files outside `lib/`.

## The source axis — 96 of 96

```sh
$ msgid-census.sh <origin/main tree> | cut -f1,2 | sort -u   ->  96
$ msgid-census.sh <ruby tree>        | cut -f1,2 | sort -u   ->  120
$ comm -23 up.keys port.keys                                 ->  (empty)
```

Nothing upstream says is missing from the port's source. The 24 rows the port
has over 96 are the census failing to resolve `_(CONSTANT)` call sites, not
new messages: the port marks at the constant's definition with `N_()` and
translates at the call site with `_()`, which is the correct idiom and which
`rxgettext` resolves. Thirteen such sites, all checked:

| Constant | File | In the emitted `.pot`? |
|---|---|---|
| `NO_DATE` | `date_row.rb:30` | ✓ |
| `YES`, `NO` | `details_list.rb:34-35` | ✓ |
| `DETAILS_TITLE` | `document_view.rb:44` | ✓ |
| `TITLE`, `HEADING`, `PASSWORD_LABEL`, `DECRYPT_LABEL` | `password_dialog.rb:28-31` | ✓ |
| `UNKNOWN`, `NOT_COMPLIANT`, `NO_PREFERENCES` | `pdf_strings.rb` | ✓ |
| `BODY` | `save_changes_dialog.rb:32` | ✓ (adjacent literals, joined by the parser as the comment there claims) |
| `TITLE` | `window.rb` | ✓ |

Checked in particular, because each is the kind of thing that breaks silently:

- The ten `msgctxt "shortcut window"` pairs are written out as literals at
  every `p_()` call site (`shortcuts_dialog.rb:49-67`), with the context
  spelled byte for byte. All ten reach the catalogue with their context.
- `translator_credits` is present with its `TRANSLATORS:` comment
  (`about_dialog.rb:50-51`), so the eighteen catalogues' credit lines reach
  the About dialog.
- No interpolation anywhere in a marked string. The one long msgid is built
  from adjacent literals, which the parser joins before extraction, and the
  port says so in the comment above it.
- Mnemonic underscores survive: `_New Window`, `_Save`, `Save _As…`,
  `Open _With…`, `_Keyboard Shortcuts`, `_About Paper Clip`, `_Cancel`,
  `_Discard`.

## The languages — carried across intact

```sh
$ diff <upstream>/po/LINGUAS po/LINGUAS                 ->  identical
$ for f in <upstream>/po/*.po; do diff -q "$f" po/; done ->  no differences
```

All eighteen — bg cs de es eu fr he hi hr it nb nl oc pt_BR ru tr uk zh_CN —
byte-identical. `Rakefile:198-211` compiles each one named in `LINGUAS` into
`locale/<lang>/LC_MESSAGES/pdf-metadata-editor.mo`, and
`spec/paper_clip/translations_spec.rb` runs a child process with `LANGUAGE`
set to prove a real catalogue is loaded at runtime. This half is clean.

## Gap 1 — the port's `.pot` loses five upstream msgids

`po/pdf-metadata-editor.pot` contains 91 keys. Upstream's source has 96.

| Missing key | Where the port still shows it |
|---|---|
| `Edit PDF document metadata` | `data/…desktop.in:7` — `Comment=` |
| `PDF;Metadata;Editor;` | `data/…desktop.in:13` — `Keywords=` |
| `New Window` | `data/…desktop.in:20` — the `[Desktop Action new-window]` name |
| `Edit the title, author, keywords and more details of your PDF documents` | `data/…metainfo.xml.in` — `<summary>` |
| `Edit pdf metadata…` | `data/nautilus-extension/paper-clip.py` — the context-menu item |

Three of those five are in **upstream's own `.pot`**, so this is a regression
the port introduced rather than an extraction upstream also missed.

**Why.** `Rakefile:192-194`:

```ruby
def gettext_sources
  Dir.glob("lib/**/*.rb") + Dir.glob("exe/*")
end
```

`po/POTFILES` lists the four data files at its top — `desktop.in`,
`gschema.xml`, `metainfo.xml.in`, `nautilus-extension/paper-clip.py` — and
nothing in the port reads `POTFILES`. Upstream's `i18n.merge_file` and
`po/meson.build` did. The declaration survived the port; the extraction did
not.

**Cost to a user.** The five strings are the ones a user meets *before the app
starts*: the launcher's subtitle, the words GNOME Shell searches when they
type "pdf", the right-click *New Window* action, the GNOME Software summary,
and the Nautilus context-menu entry. They are translated today only because
the eighteen `.po` files still carry them. The first `msgmerge` against this
`.pot` — the ordinary way a translator refreshes a catalogue — marks all five
`#~` obsolete in all eighteen languages, and the next cleanup deletes them.
Ninety translations of five strings, discarded by a glob.

**Remedy.** Extract the data files too, by type, and keep driving the list off
`po/POTFILES` so the declaration and the extraction cannot drift again:

```
xgettext --language=Desktop  data/…desktop.in
xgettext --its=…/metainfo.its data/…metainfo.xml.in
xgettext --language=Python   data/nautilus-extension/paper-clip.py
```

## Gap 2 — upstream's `.pot` was overwritten, and the Rakefile says it was not

`Rakefile:214-223` is a task named `gettext:pot` whose comment reads:

> Written beside upstream's `.pot` rather than over it: upstream's is the
> record of what translators were given, and this one is the check that every
> key the port shows still reaches a catalogue.

and whose output path is `po/pdf-metadata-editor.port.pot`.

Neither half describes this repository:

```
$ ls po/*.pot
po/pdf-metadata-editor.pot          # POT-Creation-Date: 2026-11-02 07:16
                                    # references ../lib/paper_clip/*.rb
$ git log --oneline --follow -- po/pdf-metadata-editor.pot
58304d4 Port the password dialog, the XMP write-back and the message catalogue
```

There is no `.port.pot`. The file sitting at upstream's filename *is* the
generated one, and upstream's `.pot` — the record of what the eighteen
translator teams were actually handed — was never committed to this branch at
all. A translator who pulls `po/pdf-metadata-editor.pot` expecting upstream's
catalogue gets the port's, five keys short, and nothing in the file says so.

**Remedy.** Commit upstream's `.pot` under its own name, write the generated
one to `po/pdf-metadata-editor.port.pot` as the task already says it does, and
close Gap 1 so the two agree.

## Recorded, not a gap

**The port's `desktop.in` adds a `Comment=` key that upstream's does not
have.** `Comment=Edit PDF document metadata` at line 7. Upstream's current
`desktop.in` has no `Comment`; the msgid is nevertheless in upstream's `.pot`
and in all eighteen `.po` files, left over from an earlier revision. So the
addition is translated into eighteen languages on day one and costs nothing —
it is an improvement, and it is an *extra* relative to upstream, which is why
it is written down here rather than left for someone to find in a diff. (It
is also, as `test-parity.md` notes, an edit to a file nothing validates.)

**`gettext-domain` in the gschema** moves from `pdf_metadata_editor` to
`pdf-metadata-editor`. The schema declares no translatable strings, so no key
moves; the port's domain name is the one the `.mo` files are installed under,
and the change is consistent with the rest of the port. Recorded.

## Rules observed

- The key is the `(msgctxt, msgid)` pair throughout; contexts are compared,
  not stripped.
- No upstream msgid was reworded to match the port. Where the port's wording
  would be better it stays unchanged.
- "The data files are not Ruby" would be a reason the gap is awkward, not a
  reason it is not a gap. Both gaps are counted.
- The source axis passing is reported as 96/96 and does **not** license a
  clean verdict, because the catalogue is the artifact translators consume.
