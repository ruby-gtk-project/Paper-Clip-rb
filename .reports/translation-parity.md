# Translation parity — Paper Clip

> **Round 2 note.** This document is the round-1 audit and is kept as the
> record of what the port looked like then: 96 upstream keys, 0 in the port.
> Round 2 closed all 96. The maintained count, the census commands and the
> extraction check now live in the Translation section of
> `COMPONENT_PARITY.md` at the branch root, and the two upstream `POTFILES`
> problems this audit found are in `FINDINGS.md` §5. Every row below that
> says "gap" has been closed; none of them was closed by rewording an
> upstream msgid.

| | |
|---|---|
| Upstream | `origin/main` @ `c4db98e0bc2b8921d78c9e3fbf3d85ad2a124bd0` |
| Port | `ruby` @ `6d05c88af0f4ad6db5fbd16c88b1d4d9a93d632c` |
| Upstream keys (source side) | **96** |
| Port keys | **0** |
| Ported | **0** |
| Gaps | **96** |
| Languages upstream | **18** |
| Languages in the port | **0** |
| Translated strings upstream | **~1,490** |
| Translated strings reachable from the port | **0** |

## The measurement

```
msgid-census.sh <origin/main tree>  ->  1,734 call-site rows
  of which, excluding po/            ->    96 distinct (msgctxt, msgid) keys
  unresolved markers                 ->     0
msgid-census.sh .                    ->     0 rows
```

**The port's catalogue is empty.** Not short, not partial — empty. There is no
`_()`, no `n_()`, no `N_()`, no `C_()`, no `p_()`, no `gettext`, no
`bindtextdomain`, no `textdomain`, no `require 'gettext'` anywhere in `lib/`
or `exe/`, and no `po/` directory, no `LINGUAS`, no `POTFILES`, no `.pot`.
`lib/paper_clip/application.rb` does not do what
`src/application.vala:30-32` does, which is the three `Intl.*` calls that make
any of this work.

Upstream's 96 keys by file:

| File | Keys |
|---|---:|
| `src/Document.vala` | 29 |
| `src/window.ui` | 10 |
| `src/gtk/shortcut-window.ui` | 10 (all with `msgctxt "shortcut window"`) |
| `src/gtk/details-list.ui` | 9 |
| `src/gtk/document-view.ui` | 8 |
| `src/gtk/save-changes-dialog.ui` | 5 |
| `src/gtk/password-dialog.ui` | 4 |
| `src/gtk/date-row.ui` | 4 |
| `src/DetailsList.vala` | 4 |
| `src/application.vala` | 3 |
| `data/*.metainfo.xml.in` | 3 |
| `data/*.desktop.in` | 3 |
| `src/KeywordList.vala` | 2 |
| `src/gtk/keyword-list.ui` | 2 |
| `src/window.vala`, `src/KeywordRow.vala`, `src/DateRow.vala` | 1 each |
| `data/nautilus-extension/paper-clip.py` | 1 |

The committed `po/pdf-metadata-editor.pot` holds 87 keys against the 96 in
source — the nine-key difference is the ordinary stale-`.pot` shape the skill
describes, and the `.po` cross-check confirms it: every language file carries
between 71 and 86 translated strings.

Donated work at risk, per `po/LINGUAS`:

| | |
|---|---|
| bg 84 · cs 84 · de 83 · es 84 · eu 80 · fr 80 · he 85 · hi 85 · hr 85 | |
| it 83 · nb 83 · nl 71 · oc 84 · pt_BR 84 · ru 83 · tr 80 · uk 84 · zh_CN 86 | |
| **total** | **~1,490 translated strings across 18 languages** |

All of it is currently unreachable from this port.

## The ledger

Every row below is state **`gap`**. There is no `ported` row in this document
because there is no marked string in the port.

The 96 split three ways, and the split is what tells you how much work each
row is:

### A — present in the port as an unmarked bare literal (85 keys)

The bytes are right and no marker is around them, so the key never reaches a
catalogue. This is the cheapest class to close and the one that is invisible in
every English screenshot.

| Key | Port site |
|---|---|
| `Paper Clip` | `window.rb:40`, `about_dialog.rb:22` |
| `Select a File` | `window.rb:155` |
| `Open` | `window.rb:163` |
| `Open a Document` | `window.rb:45` (welcome) **and** `window.rb:291` (file-dialog title — a site upstream does not have) |
| `Drag and drop a PDF file here` | `window.rb:46` |
| `_New Window` · `_Save` · `Save _As…` · `Open _With…` · `_Keyboard Shortcuts` · `_About Paper Clip` | `primary_menu.rb:19-30` |
| `Title` · `Author` · `Creation Software` · `Subject` · `Conversion Software` | `document_view.rb:35-39` |
| `Creation Date` · `Modification Date` | `document_view.rb:144-145` |
| `Non-Editable Properties` | `document_view.rb:41` |
| `Keyword` | `keyword_row.rb:15` |
| `Keywords` | `keyword_list.rb:20` |
| `Add Keyword` | `keyword_list.rb:21` |
| `Add a keyword` | `keyword_list.rb:68` |
| `Delete Keyword` | `keyword_row.rb:33` |
| `No date set` · `Remove Date` · `Show Calendar` · `Today` · `Tomorrow` | `date_row.rb:16,60,68,99` |
| `Format` · `Layout` · `Duplex` · `Subtype` · `Contains JavaScript` · `Contains Attachments` · `Number of Pages` | `details_list.rb:22-28` |
| `Yes` · `No` | `details_list.rb:31-32` |
| `Viewer Preferences` · `Permissions` | `details_list.rb:68-69` |
| `Save Changes?` | `save_changes_dialog.rb:21` |
| `Open documents contain unsaved changes. Changes which are not saved will be permanently lost.` | `save_changes_dialog.rb:22-23` (split across a line continuation; the *value* is byte-identical) |
| `_Cancel` · `_Discard` · `_Save` | `save_changes_dialog.rb:58-60` |
| `Unknown` | `pdf_strings.rb:15` |
| `Pages in one column` · `One page at a time` · `Odd numbered pages on the left` · `Odd numbered pages on the right` · `Two odd numbered pages on the left` · `Two odd numbered pages on the right` · `No specific layout` | `pdf_strings.rb:18-27` |
| `Flip on the long edge` · `Flip on the short edge` · `Only single sided` · `No preference` | `pdf_strings.rb:30-36` |
| `Not compliant` | `pdf_strings.rb:49` |
| `Center document's window` · `Reading order is right to left` · `Display document's title` · `Fit document to window` · `Hide window menubar` · `Hide window toolbars` · `Hide UI elements` · `No preferences` | `pdf_strings.rb:54-64` |
| `Adding notes` · `Inserting elements` · `Copying` · `Extracting contents` · `Filling interactive forms` · `Modifying` · `Printing` · `Printing in high resolution` | `pdf_strings.rb:70-79` |
| `Open a new window` · `Print version information and exit` | `main.rb:17-18` — **in a comment, not in code.** The two option descriptions upstream registers as `N_()` (`application.vala:47-48`) appear in the port only inside a docstring, so `paper-clip --help` prints nothing for either flag |

### B — present in the port with the wrong msgctxt (10 keys)

Upstream's shortcut-window strings all carry `msgctxt "shortcut window"`
(`src/gtk/shortcut-window.ui:9-77`). `shortcuts_dialog.rb:16-29` has the
English and no context, so even once marked these would be ten *new* keys and
the eighteen catalogues' translations of the originals would still be
unreachable. Counted once each, in the 96, as gaps:

`("shortcut window", "General")` · `Quit` · `New window` · `Close window` ·
`Keyboard Shortcuts` · `("shortcut window", "Editor")` · `Open` · `Save` ·
`Save As…` · `Add a keyword`

### C — absent from the port entirely (11 keys)

| Key | Why it is gone |
|---|---|
| `This Document Is Encrypted` | `src/PasswordDialog.vala` has no port file |
| `Password Dialog` | ditto |
| `Password` | ditto |
| `Decrypt` | ditto |
| `Failed to open the document. The provided password is incorrect.` | **reworded.** `window.rb:53` says `Failed to open the document. It is encrypted.` This is two gaps, not one: upstream's key is missing, and the port has an extra key nobody has translated |
| `translator_credits` | `about_dialog.rb` sets nine About properties and not this one, so no translator's name is ever shown in any of the 18 languages |
| `Edit PDF document metadata` | `data/*.desktop.in` not ported |
| `PDF;Metadata;Editor;` | ditto — the desktop file's search keywords |
| `Edit the title, author, keywords and more details of your PDF documents` | `data/*.metainfo.xml.in` not ported |
| `Edit pdf metadata…` | `data/nautilus-extension/paper-clip.py` not ported |
| `New Window` | the desktop file's `New Window` action name |

## Extra keys the port invented (6)

Each is an untranslated string a user can see, with no upstream counterpart.
They are outside the 96 and they are still gaps, because the port now has keys
nobody has translated:

| String | Site |
|---|---|
| `Failed to open the document. It is encrypted.` | `window.rb:53` |
| `Failed to open the document.` | `window.rb:54` |
| `That file is not a PDF.` | `window.rb:55` |
| `Failed to save the document.` | `window.rb:417` |
| `Open menu` | `shortcuts_dialog.rb:21` |
| `A Ruby GTK4 and Libadwaita port of Paper Clip, the PDF metadata editor.` | `about_dialog.rb:29` |

Plus `unknown` (`about_dialog.rb:66`, `about_dialog.rb:88`), which reaches the
About dialog's debug block in lowercase English.

## An upstream bug found en route

`po/POTFILES` lists 17 files. It does **not** list `src/DetailsList.vala`,
`src/KeywordList.vala`, `src/KeywordRow.vala`, `src/DateRow.vala`,
`src/window.vala`, `src/StringArrayRow.vala` or `src/SaveChangesDialog.vala` —
but it does list `data/io.github.diegoivan.pdf_metadata_editor.appdata.xml.in`,
a filename that no longer exists on `origin/main` (the file is now
`...metainfo.xml.in`). So upstream's `POTFILES` references a deleted file and
omits seven live ones. Several of those omitted files' strings do appear in the
`.po` catalogues, which means the list has drifted since the last successful
extraction rather than those strings never having been offered. Worth
reporting upstream. The port must carry every one of the 96 keys regardless,
and list its own files in its own `POTFILES`.

## What closing this looks like

1. Copy `po/` from `origin/main` into the port unchanged — all 18 `.po` files,
   `LINGUAS`, and a `POTFILES` rewritten to name the port's `lib/**/*.rb`.
2. Add the `gettext` gem, call `bindtextdomain`/`textdomain` for
   `pdf-metadata-editor` at startup where `application.vala:30-32` does, and
   build and install a `.mo` per language.
3. Wrap all 85 class-A literals in `_()` **without changing one byte of them**.
4. Mark the ten class-B strings with `p_('shortcut window', …)` so the context
   matches.
5. Revert `window.rb:53` to upstream's sentence, build the password dialog
   that sentence belongs to, and mark its four strings.
6. Set `translator_credits`.
7. Port the desktop entry, the metainfo and the Nautilus extension so their
   five keys come back.
8. Re-run the census and diff. Parity is `96/96, 0 gaps` or it is not parity.

No row here may be closed by rewording upstream's msgid to match the port.
Upstream's bytes are the ones 18 catalogues are keyed on.
