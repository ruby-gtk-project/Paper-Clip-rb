# Test parity — Paper-Clip-rb

| | |
|---|---|
| Upstream | `origin/main` @ `c4db98e0bc2b8921d78c9e3fbf3d85ad2a124bd0` |
| Port | `ruby` branch, round 8 |
| Upstream tests | **3** |
| Ported and verified passing | **3** |
| Unverified | **0** |
| Gaps | **0** named upstream-test gaps, **0** drive-coverage gaps on port-added behaviour — the 5 that stood as of round 7 (`Thumbnailer::ExportError`/`CacheError`, `@loading`, `@syncing`, `proceed_with_state`) are all closed this round; see `PORTING.md`'s "Open gaps" 14–18 |
| Port tests (Extra) | **130 examples, 0 failures** + a 318-check drive harness. This said 134 before round 7; the per-file table below it has always summed to 130 (41+35+17+19+8+10), and nobody added the column before writing the header. See `.reports/accountability-ensurance.md`, Finding 2. |
| Test command | `nix develop --command rspec --require ./spec/spec_helper.rb -Ilib -Ispec spec` |
| Data validation command | `nix develop --command rake test:data` |

## Upstream has three declared tests, not zero

An earlier round of this document reported **0 upstream tests, 0 gaps**, on
this evidence:

```
grep -rn 'test' meson.build src/meson.build   ->  nothing
```

That grep is true for those two files and the conclusion it supported was
false: it never looked at the third `meson.build`, `data/meson.build`, which
declares three:

```
$ git grep -n "test(" origin/main -- '*meson.build'
origin/main:data/meson.build:12:  test('Validate desktop file', desktop_utils, args: [desktop_file])
origin/main:data/meson.build:25:  test('Validate appstream file', ...)
origin/main:data/meson.build:38:  test('Validate schema file', ...)
```

Upstream still has no unit-test suite in the `g_test_add`/`pytest` sense — no
`test/` or `tests/` directory exists anywhere in its tree — but `ninja test`
runs these three and a red one fails the build. They are tests by the only
definition that matters here, and this ledger previously undercounted them
by 3 for four days and six commits after `.reports/test-parity.md` had
already corrected it. See `.reports/accountability-ensurance.md`, Finding 2.

## Suite: `data/meson.build` — 3 tests, 3 verified passing

| # | Upstream test | What it asserts | Port | Status |
|---|---|---|---|---|
| 1 | `Validate desktop file` (`data/meson.build:12`) | the merged `.desktop` passes `desktop-file-validate` | `rake test:data` | **ported, runs, verified this round** — one hint about upstream's own `Categories` key (`GTK;Utility;Office;` names more than one main category), not a failure |
| 2 | `Validate appstream file` (`data/meson.build:25`) | the merged metainfo passes `appstreamcli validate --no-net --explain` | `rake test:data` | **ported, runs, verified this round** — `Validation was successful: infos: 2, pedantic: 4` |
| 3 | `Validate schema file` (`data/meson.build:38`) | `data/*.gschema.xml` passes `glib-compile-schemas --strict --dry-run` | `rake test:data` | **ported, runs, re-confirmed this round** |

`rake test:data` merges `data/*.in` through `msgfmt --desktop`/`--xml` the
same way `flake.nix`'s `installPhase` does, then runs the three validators
against the merged files, each gated on `find_executable0` exactly as
upstream gates them on `find_program(..., required: false)`. `flake.nix`'s
devShell now lists `pkgs.desktop-file-utils` and `pkgs.appstream` alongside
`glib`, so all three checks run for real in this devShell — confirmed by
running `nix develop --command rake test:data`, which executed all three and
printed each tool's own verdict rather than a skip note.

## Extra — the port's own suites

Outside the 3/3 count, because upstream owes none of it.

### `spec/` — 130 examples, 0 failures (this row said 134; its own column sums to 130)

| File | Examples | What is pinned |
|---|---:|---|
| `spec/paper_clip/document_spec.rb` | 41 | the PDF date parser and formatter (`document.rb` `parse_date`/`format_date`), the `$TMPDIR/copies` cached copy and the original's immutability, the Info read, the page count and its zero case, the keyword comma split and round trip, the change-notification contract, and the incremental-update writer: original bytes kept, `/Prev` chained, a classic table with twenty-byte entries, offsets that point at the objects they describe, two saves in a row, UTF-16BE behind a BOM, and literal escaping |
| `spec/paper_clip/pdf_crypt_spec.rb` | 35 | the standard security handler, RC4-40/128 and AES-128/256 against four fixture PDFs, for each of `/R` 2, 3, 4, 5 and 6 |
| `spec/paper_clip/xmp_packet_spec.rb` | 17 | the XMP mirror: attribute-carried and element-carried properties updated in place, `dc:title` as an `x-default` language alternative, a property added where the packet had none, `MetadataDate` stamped, ISO 8601 with offsets, `CreateDate`/`ModifyDate` deleted rather than blanked, an unrelated schema left alone, the xpacket envelope kept, XML escaping, the `xmp:`/`xap:` prefix choice, a packet with no matching `rdf:Description`, and the whole thing through `Document#save` |
| `spec/paper_clip/pdf_strings_spec.rb` | 19 | every `/PageLayout` and `/Duplex` name and both fallbacks, the subtype prefixes, the viewer-preference table including `/Direction` as a name and an explicit `false`, and the `/Encrypt /P` bit mapping: each bit alone, none, `-1`, `-4`, and `-4` with printing or copying revoked |
| `spec/paper_clip/document_manager_spec.rb` | 8 | the dirty flag: clean on assignment, dirty on a real edit, clean on a no-op edit, dirty on a keyword add, reset when a document is replaced, and — the bug this spec found — **not** raised by a notification from a document the manager no longer owns |
| `spec/paper_clip/translations_spec.rb` | 10 | the domain is upstream's `pdf-metadata-editor` and not the gem's name, the catalogue directory, the markers an includer gets, the `N_`/`_` split, and German and French lookups against the compiled catalogues — including one keyed on `(msgctxt, msgid)`, which is the check that would have caught the shortcuts dialog's missing context |

Fixtures: `spec/support/pdf_fixtures.rb` generates the unencrypted ones, so
their byte offsets cannot drift out of step with their own cross-reference
tables. The four encrypted ones are committed, with their provenance, in
`spec/fixtures/README.md`: they were produced by `qpdf`, because a fixture
produced by the code under test proves nothing about it.

Two things found by writing this suite rather than by reading the code:

- **`DocumentManager` followed a replaced document's changes.** The closure it
  registered on `on_change` stayed live as long as anything else held the old
  document — and the save-changes dialog holds exactly that. Fixed with an
  identity check in `mark_changed`.
- **`/P` `-4` permits everything.** The two low bits of `/Encrypt /P` are
  reserved and always clear, so the permissive value is `-4`, not `-1`. The
  first draft of the spec asserted that `-4` revoked printing, and the code
  was right.

### `test/drive_paper_clip.rb` — 318 checks, 124 steps, 19 screenshots

The harness builds the real application under `xvfb-run`, opens the real
windows and dialogs, loads real PDFs off disk including a genuinely AES-128
encrypted one, and asserts the observable result of each interaction. See
`COMPONENT_PARITY.md` for what it did and did not reach.

**Closed in round 5:** `Thumbnailer#load_scaled`'s PNG-cache branch and the
renderer's actual output were previously unexercised by any committed
fixture — every PDF the suite built was 200×200, far under the 306,250px
threshold the branch requires. `PdfFixtures.big` is a 600×600 page carrying
an actual content stream (a filled black rectangle over its bottom half, not
a blank page), and the harness loads it, reads the PNG `write_to_png` wrote
back out of `$TMPDIR/thumbnails/`, and checks for a pixel darker than the
white backing rectangle — proving the branch renders the document rather
than drawing nothing.

**Closed this round:** the five checks the previous round's "Owed" section
below named. 35 of the 318 checks and 23 of the 124 steps are new this
round:

- **`Thumbnailer::ExportError`** — `create_cache_file` is pointed at a path
  whose parent directory does not exist, so `write_to_png` fails for real.
  Driving this found that the rescue clause never worked: `write_to_png`'s
  actual failure is `Cairo::WriteError`, a Ruby `IOError`, not a
  `Cairo::Error`, so `thumbnailer.rb#export`'s
  `rescue Cairo::Error, SystemCallError` let it straight through. Fixed by
  also rescuing `IOError`.
- **`Thumbnailer::CacheError`** — `Dir.tmpdir` is pointed at a path that is
  a plain file, so `FileUtils.mkdir_p` underneath it fails with
  `Errno::ENOTDIR`; `CacheError` is asserted, and so is `Dir.tmpdir` being
  restored afterward.
- **`DocumentView`'s `@loading` guard** — forced true directly, then a row
  is edited to a value the open document does not have; neither the
  document nor the dirty flag follows it while the guard holds, and the
  real write-back path is confirmed to still work once it is released.
- **`DateRow`'s `@syncing` guard** — the row's own `on_change` is wrapped in
  a spy; assigning a date from outside re-points the calendar, which fires
  its own `day-selected`, and the spy is asserted not to have been
  re-entered. A real pick afterward is asserted to fire the spy exactly
  once, proving the guard suppresses only the sync window.
- **`proceed_with_state`'s three call sites** — the `saved` site was
  already reached by the existing Save-and-close steps. The harness now
  also answers Discard on a window with unsaved work and confirms it closes
  with nothing written, and separately unticks the one document in the
  save-changes dialog before pressing Save and confirms the same for the
  empty-selection branch of `save_selected`.

## Owed

Nothing. The three checks an earlier brief named and the two `Thumbnailer`
error domains are all driven as of this round; see "Closed this round"
above and `PORTING.md`'s "Open gaps" 14–18.

## Harness

`spec/spec_helper.rb` is the kettle-jem scaffold. Two round-1 problems with it
are fixed:

- it required `paper/clip/rb`, which did not exist, so `rake spec` raised
  `LoadError` before running anything. `lib/paper/clip/rb.rb` now exists;
- it required `kettle/test/rspec` unguarded, and `kettle-test` is not
  packaged in this environment. That require is now wrapped in the same
  `rescue LoadError` the scaffold already uses for `kettle-soup-cover`, and
  nothing in `spec/` depends on the harness helpers.

`rake spec` works wherever the kettle stack installs; here the suite runs
under `rspec` directly.

## Rules observed

- The upstream census was re-derived from the build files, not inherited.
  That is how the count is 3 and not 0.
- No gap was lowered, merged or marked `n/a`.
- Everything the port wrote beyond the 3/3 count is under `## Extra`.
- Where a validator used by a ported test is missing from this sandbox, the
  task says so and skips rather than claiming a pass it did not run.
