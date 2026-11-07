# Component identification — Paper Clip (round 8 audit)

| | |
|---|---|
| Upstream | `origin/main` @ `c4db98e0bc2b8921d78c9e3fbf3d85ad2a124bd0` (2025-04-28) |
| Port | `ruby` @ `60ffe4d` (re-verified fresh for this audit) |

One commit landed since round 7's audit (`1a00aac`): `60ffe4d`, "Drive
Thumbnailer's two error branches and the three re-entrancy guards". Per
`git show --stat 60ffe4d`, it touched `lib/paper_clip/thumbnailer.rb` (9
lines — the `IOError` rescue fix), `test/drive_paper_clip.rb` (+248 lines)
and three prose ledgers (`PORTING.md`, `COMPONENT_PARITY.md`,
`TEST_PARITY.md`). No new `lib/` file, no deleted `lib/` file, no file
renamed. So this round re-ran the full sweep below rather than assuming the
inventory could not have moved — it is confirmed unchanged, not skipped.

| Upstream `.vala` units | **16** (`src/*.vala`, `src/Services/*.vala`, `src/Models/*.vala`) |
| Upstream standalone `.ui`/non-widget units | `src/gtk/shortcut-window.ui` (no backing `.vala`) |
| Upstream non-source units outside `src/` | `data/*.in`, `data/*.gschema.xml`, `data/icons/**`, `data/nautilus-extension/paper-clip.py`, `po/**` |
| Port `lib/paper_clip/*.rb` files | **29** |
| Upstream units with no port file at all | **0** |
| Port files with no upstream file opposite | **1**, explained (`poppler.rb` — Vala gets poppler-glib from a VAPI; the port gets it from a typelib the flake builds) |

## The sweep, re-run fresh this round

```sh
$ git show --stat 60ffe4d
 COMPONENT_PARITY.md           |  44 +++--
 PORTING.md                    |  89 ++++++------
 TEST_PARITY.md                |  60 +++++---
 lib/paper_clip/thumbnailer.rb |   9 +-
 test/drive_paper_clip.rb      | 248 ++++++++++++++++++++++++++++++++++++
$ find lib/paper_clip -name '*.rb' | wc -l
29
$ for f in date_row details_list document_view keyword_list keyword_row \
           string_array_row drop_overlay save_changes_dialog document_row \
           password_dialog document_thumbnail thumbnailer document document_manager \
           thread_manager translations window window_state primary_menu \
           application about_dialog main style shortcuts_dialog pdf_strings \
           pdf_crypt poppler xmp_packet models version; do
    test -f "lib/paper_clip/${f}.rb" || echo "MISSING: $f"
  done
# (no output — all 29 named files present)
```

No upstream `.vala`/`.ui` unit lost its port file, and no new upstream unit
appeared on `origin/main` to go unmapped — `origin/main` is at the same
commit it was for round 7.

## Driven, not just read

```sh
$ nix develop --command xvfb-run -a ruby test/drive_paper_clip.rb
... (full run, captured live this round)
318 of 318 checks passed
DRIVE OK
```

Re-run fresh for this audit, not quoted from the commit message: exit 0,
318/318. Up from round 7's 283/283 — the 35-check increase is exactly the
five drive-coverage gaps `60ffe4d` closed (two `Thumbnailer` error domains,
three re-entrancy guards), confirmed by reading the diff in
`test/drive_paper_clip.rb` directly (see `component-parity.md` for the
behaviour each new block proves, not just its presence).

## What this round re-confirmed rather than re-derived

Everything round 7 already settled here (the three gaps closed in round 3 —
`DocumentThumbnail`, `Services/Thumbnailer`, the D-Bus `.service.in` — and
the `poppler.rb`/`gresource.xml` correspondences) is unchanged, because no
`lib/` file was added, removed or renamed since. Re-checked by the `test -f`
sweep above rather than assumed.

## Rules check

- No widget type was reported without reading the file it comes from in
  this round: the file list above was re-run against the current tree, not
  carried from `component-identification.md`'s round-7 text.
- `poppler.rb` is called out explicitly as a port-only file, per the
  skill's rule that an unexplained extra is the common way a correct port
  reads as a gap.
- The drive total is quoted from a run executed in this session, not from
  `PORTING.md`'s prose.
