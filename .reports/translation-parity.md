# Translation parity — Paper Clip

| | |
|---|---|
| Upstream | `origin/main` @ `c4db98e0bc2b8921d78c9e3fbf3d85ad2a124bd0` (2025-04-28) |
| Port | `ruby` branch, this audit |
| **messages (msgctxt, msgid) pairs** | **96 / 96** |
| occurrences (call sites) | 123 port / 100 upstream |
| languages | **18 / 18** |
| catalogue files | 18 `.po`, all byte-identical to upstream |
| translated strings | unchanged (no `.po` was edited) |
| `msgctxt`-carrying keys | 10 / 10 (all `"shortcut window"`) |

## Method

```sh
scripts/msgid-census.sh <upstream tree> > up.tsv     # 1734 rows
scripts/msgid-census.sh <port tree>     > port.tsv   # 1767 rows
awk -F'\t' '$4 !~ /\.pot?:/' up.tsv   | cut -f1,2 | sort -u | grep -v '^!unresolved'  # 96
awk -F'\t' '$4 !~ /\.pot?:/ && $4 !~ /^spec\//' port.tsv | ... # 96
comm -23 up.keys port.keys   ->  (empty)
comm -13 up.keys port.keys   ->  (empty)
```

**Nothing was dropped and nothing was invented.** The diff is empty in both
directions on the `(msgctxt, msgid)` key, which is what gettext looks up.

Cross-checked against a real catalogue, as the skill requires: the keys
reachable from `po/de.po` reconcile against the source census on both sides,
and the three non-code sources the scan is there to catch —
`.desktop.in` (`Name`/`Comment`/`Keywords`/action `Name`), AppStream metainfo
(`<name>`/`<summary>`/`<p>`/`<li>`/`<caption>`) and the GSettings schema —
contribute on both sides.

The 24 `!unresolved` rows on the port side are all the same construction: a
label marked `N_()` in a frozen constant table and translated with `_(CONST)`
at display. `grep -c 'N_(' lib/**/*.rb` accounts for every one of them, and
each resolves to a key already in the 96. That pattern is also what keeps the
longest msgid intact — `save_changes_dialog.rb:27-32` joins two adjacent
string literals, which `rxgettext` concatenates exactly as `xgettext`
concatenates upstream's `.ui` body property.

## Per-unit

| Upstream (occurrences) | Port (occurrences) |
|---|---|
| `src/Document.vala` (29) | `lib/paper_clip/pdf_strings.rb` (36) |
| `src/window.ui` (10) + `src/window.vala` (1) | `lib/paper_clip/window.rb` (7) + `lib/paper_clip/primary_menu.rb` (7) |
| `src/gtk/shortcut-window.ui` (10) | `lib/paper_clip/shortcuts_dialog.rb` (10) |
| `src/gtk/details-list.ui` (9) + `src/DetailsList.vala` (4) | `lib/paper_clip/details_list.rb` (14) |
| `src/gtk/document-view.ui` (8) | `lib/paper_clip/document_view.rb` (10) |
| `src/gtk/save-changes-dialog.ui` (5) | `lib/paper_clip/save_changes_dialog.rb` (7) |
| `src/gtk/password-dialog.ui` (4) | `lib/paper_clip/password_dialog.rb` (8) |
| `src/gtk/date-row.ui` (4) + `src/DateRow.vala` (1) | `lib/paper_clip/date_row.rb` (7) |
| `src/application.vala` (3) | `lib/paper_clip/about_dialog.rb` (1) + `lib/paper_clip/main.rb` (3) |
| `src/KeywordList.vala` (2) + `src/gtk/keyword-list.ui` (2) | `lib/paper_clip/keyword_list.rb` (3) |
| `src/KeywordRow.vala` (1) | `lib/paper_clip/keyword_row.rb` (2) |
| `data/*.desktop.in` (3) | same file (4) |
| `data/*.metainfo.xml.in` (3) | same file, byte-identical (3) |
| `data/nautilus-extension/paper-clip.py` (1) | same file (1) |

Occurrence counts, not key counts: the port's `N_()`-at-definition /
`_()`-at-display pattern gives most units two call sites per message, and
`details_list.rb` / `pdf_strings.rb` absorb the tables that upstream splits
between a `.ui` file and a `.vala` switch. Every key behind these rows is in
the 96 that reconcile exactly.

`po/POTFILES` is complete: every file the census finds a msgid in is listed,
and the only msgid-bearing file *not* listed is `spec/support/translated_host.rb`,
a test fixture, correctly excluded. Upstream's own `POTFILES` names
`data/…appdata.xml.in`, a file that has not existed since the metainfo rename;
the port lists `…metainfo.xml.in` and reports the upstream bug rather than
copying it (`FINDINGS.md` §5). Correct in both directions.

## Gap 1 — `po/pdf-metadata-editor.pot` was overwritten, and the replacement drops 5 of the 96 keys

The committed `.pot` is not upstream's any more:

```
$ grep -m1 POT-Creation-Date po/pdf-metadata-editor.pot
"POT-Creation-Date: 2026-11-02 07:16+0000\n"          # port's
$ git show origin/main:po/pdf-metadata-editor.pot | grep -m1 POT-Creation-Date
"POT-Creation-Date: 2024-01-27 21:42-0600\n"          # upstream's
$ grep -c '^#: ' po/pdf-metadata-editor.pot ; grep '^#: ' po/pdf-metadata-editor.pot | tr ' ' '\n' | grep -v '^#' | sed 's/:[0-9]*//' | sort -u
   # every reference is ../lib/paper_clip/*.rb — nothing from data/ or po/
```

It was regenerated from `lib/**/*.rb` + `exe/*` only. Five census keys are
therefore absent from it:

| msgid | lives in | in upstream's `.pot`? |
|---|---|---|
| `Edit PDF document metadata` | `data/*.desktop.in:7`, `data/*.metainfo.xml.in` | yes |
| `Edit the title, author, keywords and more details of your PDF documents` | `data/*.metainfo.xml.in` | yes |
| `PDF;Metadata;Editor;` | `data/*.desktop.in:13` | yes |
| `New Window` (the desktop action) | `data/*.desktop.in:20` | no |
| `Edit pdf metadata…` | `data/nautilus-extension/paper-clip.py:81` | no |

The port's own `Rakefile:213-226` says it writes
`po/pdf-metadata-editor.port.pot`, "beside upstream's rather than over it,
because upstream's is the record of what translators were given". That file
does not exist in the tree, and upstream's record is gone. The Rakefile and
the committed artifact disagree, and the artifact is the one translators would
use.

Cost to the user: a translator who regenerates from this `.pot` is never shown
the launcher comment, the search keywords, the AppStream summary, the
*New Window* desktop action or the Nautilus menu item — the five strings that
are the *only* Paper Clip text a user sees before the app has even started.
The existing 18 catalogues still carry three of them, so nothing is broken
today; the next `msgmerge` is where they disappear.

Fix: restore upstream's `.pot` from `origin/main`, and point the `pot` task at
`po/pdf-metadata-editor.port.pot` as its own comment already promises, adding
`data/*.desktop.in`, `data/*.metainfo.xml.in`, `data/*.gschema.xml` and
`data/nautilus-extension/*.py` to `gettext_sources` so the port's own
extraction covers all 96.

## Gap 2 — a gem-installed Paper Clip is untranslated in all 18 languages

`Translations::LOCALE_DIR` is `<gem>/locale`, and `locale/` is
`.gitignore`d (line 55) and untracked, so `spec.files` cannot contain it:

```
$ git ls-files locale | wc -l
0
$ grep -n 'locale' paper-clip-rb.gemspec
   (no match; spec.files enumerates lib, exe, data/**/*, po/**/*)
```

The gem ships 18 `.po` files and no `.mo` file, and nothing compiles them at
install time. `rake gettext:mo:update` exists (`Rakefile:198-212`) and only a
developer runs it. The same gap covers the two merged artifacts: the
`msgfmt --desktop` / `msgfmt --xml` merges that put translated `Comment`,
`Keywords` and `<summary>` into the installed files live only in
`flake.nix:181-193`.

Cost to the user: `gem install paper-clip-rb && paper-clip` gives an
English-only application in every one of the 18 languages upstream ships, and
an English-only launcher entry. Nix users are unaffected — `flake.nix:165-175`
compiles the catalogues correctly.

Fix: either un-ignore `locale/` and commit the compiled `.mo` files, or add a
`gettext:mo:update` dependency to the build task and list `locale/**/*` in
`spec.files`.

## Checks that did not run

- **`msgfmt --statistics` per catalogue** — `msgfmt` is not on the host and is
  not in the devShell's `PATH` (only in the Nix build's). The translated /
  fuzzy / untranslated split per language is therefore **not measured** in
  this report. It is safe to say it is unchanged, because all 18 `.po` files
  are byte-identical to upstream (`diff` clean, 18/18), but the number itself
  was not taken.
- **Runtime lookup in a non-English locale against the real widgets** — blocked
  by the same `Gtk::InitError` as everything in `component-parity.md`.
  `spec/paper_clip/translations_spec.rb` does verify the lookup in a child
  process with `LANGUAGE` set, so the domain, the path and `p_()` resolution
  are proven; what is unproven is that a translated string reaches a widget.

## Rules observed

- Reported as pairs against upstream, not as adjectives: `96/96 · 18/18 · 123/100`.
- The occurrence count is reported even though it is not the pass condition.
- Both unrun checks are named as unrun.
- No key was excused, merged or renamed; no `.po` file was edited.
