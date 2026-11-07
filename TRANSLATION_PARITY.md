# Translation parity — Paper-Clip-rb

| | |
|---|---|
| Upstream | `origin/main` @ `c4db98e0bc2b8921d78c9e3fbf3d85ad2a124bd0` |
| Port | `ruby` branch, round 4 |
| Upstream keys (`msgctxt`, `msgid`) in source | **96** |
| Present in the port's source, byte-identical | **96** |
| Reworded, retyped or unmarked | **0** |
| Present in the catalogue `rake gettext:pot` now emits | **96** (was 91 before this round) |
| Upstream keys the port's `.pot` loses | **0** (was 5) |
| Languages | 18 upstream, 18 in the port, `LINGUAS` and all 18 `.po` files byte-identical |
| Gaps | **0** |

Two different questions, and the port now passes both. Every string in the
port's Ruby *says* what upstream said, and the catalogue the port *produces*
now carries every one of those 96 keys — not just the ones that happen to
live under `lib/` and `exe/`.

## The source axis — 96 of 96

```
$ msgid-census.sh <origin/main tree> | cut -f1,2 | sort -u   ->  96
$ msgid-census.sh <ruby tree>        | cut -f1,2 | sort -u   ->  120
$ comm -23 up.keys port.keys                                 ->  (empty)
```

Nothing upstream says is missing from the port's source. The 24 rows the port
has over 96 are the census failing to resolve `_(CONSTANT)` call sites, not
new messages: the port marks at the constant's definition with `N_()` and
translates at the call site with `_()`, which is the correct idiom and which
the extraction below resolves.

The ten `msgctxt "shortcut window"` pairs are written out as literals at
every `p_()` call site (`shortcuts_dialog.rb:49-67`), with the context
spelled byte for byte, and `translator_credits` is present with its
`TRANSLATORS:` comment (`about_dialog.rb:50-51`). No interpolation appears
in any marked string.

## The languages — carried across intact

```
$ diff <upstream>/po/LINGUAS po/LINGUAS                 ->  identical
$ for f in <upstream>/po/*.po; do diff -q "$f" po/; done ->  no differences
```

All eighteen — bg cs de es eu fr he hi hr it nb nl oc pt_BR ru tr uk zh_CN —
byte-identical. `Rakefile`'s `gettext:mo:update` compiles each one named in
`LINGUAS` into `locale/<lang>/LC_MESSAGES/pdf-metadata-editor.mo`, and
`spec/paper_clip/translations_spec.rb` runs a child process with `LANGUAGE`
set to prove a real catalogue is loaded at runtime.

## What closed this round — the port's `.pot` no longer loses 5 keys

`po/pdf-metadata-editor.pot` is upstream's own donated catalogue again,
restored verbatim (`git show origin/main:po/pdf-metadata-editor.pot`) rather
than the port's generated output sitting under upstream's filename. The
port's own extraction now lands beside it, at
`po/pdf-metadata-editor.port.pot`, exactly as `Rakefile`'s `gettext:pot` task
comment always claimed it did.

The five keys that were missing are now extracted:

| Key | Source | Extractor |
|---|---|---|
| `Edit PDF document metadata` | `data/…desktop.in` `Comment=` and `data/…metainfo.xml.in` `<summary>` | `xgettext --language=Desktop` / `--its=po/its/metainfo.its` |
| `PDF;Metadata;Editor;` | `data/…desktop.in` `Keywords=` | `xgettext --language=Desktop` |
| `New Window` | `data/…desktop.in`, `[Desktop Action new-window]` `Name=` | `xgettext --language=Desktop` |
| `Edit the title, author, keywords and more details of your PDF documents` | `data/…metainfo.xml.in` `<description><p>` | `xgettext --its=po/its/metainfo.its` |
| `Edit pdf metadata…` | `data/nautilus-extension/paper-clip.py` | `xgettext --language=Python` |

**Why it was losing them, and what changed.** `Rakefile`'s `gettext_sources`
used to be `Dir.glob("lib/**/*.rb") + Dir.glob("exe/*")` — a glob that never
looks at `po/POTFILES`, which still lists the four data files above.
`rxgettext` (the Ruby gettext gem) can only parse Ruby, so it could not have
extracted them anyway. The fix drives the source list off `po/POTFILES`
itself (`gettext_potfiles`), splits it into the `lib/`/`exe/` paths (still
extracted with `rxgettext`) and the `data/` paths, extracts each data file
with the *system* `xgettext` using the language or ITS rule file its format
needs (`gettext_xgettext_args_for`), and merges every fragment with `msgcat`
into `po/pdf-metadata-editor.port.pot`. Declaring a file in `POTFILES` and
extracting it can no longer drift apart silently, because
`gettext_xgettext_args_for` raises for any `POTFILES` entry it does not
recognise instead of skipping it.

Two small ITS 2.0 rule files back the XML extractions, committed under
`po/its/`:

- `po/its/metainfo.its` — marks `name`, `summary` and the top `description`'s
  `p` translatable, and anything carrying `translatable="no"` (the release
  notes block and the `developer`/`developer_name` tags) not translatable,
  matching upstream's own AppStream conventions. Verified to extract exactly
  the three keys upstream's own `.pot` has from this file, no more.
- `po/its/gschema.its` — marks a GSettings key's `summary`/`description`
  translatable. The port's schema declares no keys, so this correctly
  extracts zero strings rather than silently matching the wrong elements if
  one is ever added.

## Rules observed

- The upstream census was re-derived from source, not inherited.
- No gap was lowered, merged or marked `n/a`.
- `po/pdf-metadata-editor.pot` is upstream's record, unmodified; the port's
  own check lands at its own filename, `po/pdf-metadata-editor.port.pot`
  (gitignored — it is a build artifact of `rake gettext:pot`, not a
  translator-facing file).
