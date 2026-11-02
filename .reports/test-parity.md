# Test parity — Paper Clip

| | |
|---|---|
| Upstream | `origin/main` @ `c4db98e0bc2b8921d78c9e3fbf3d85ad2a124bd0` (2025-04-28) |
| Port | `ruby` @ `3800624` |
| Upstream tests | **3** |
| Ported | **0** |
| Gaps | **3** |
| Port tests (Extra) | **134 examples, 0 failures** + a 278-check drive harness |
| Suites executed for this audit | both, from a clean shell |

## Both suites were run, not quoted

```
$ nix develop --command rspec --no-color -f progress
134 examples, 0 failures   (2.01s, seed 63595)

$ nix develop --command xvfb-run -a ruby test/drive_paper_clip.rb
278 of 278 checks passed
DRIVE OK                                   (exit 0)
```

Last round's copy of this document could not say that, and the root
`TEST_PARITY.md` still cannot — see the ledger problem below.

## The upstream count is 3, and the root ledger still says 0

Upstream has no unit tests: no `test/`, no `tests/`, no `Test.add_func`, no
`g_test_add`, no `pytest`. `test-census.sh` over the upstream tree returns
zero rows, correctly.

It has three declared, named, `meson test`-runnable tests:

```
$ git grep -n 'test(' origin/main -- '*meson.build'
origin/main:data/meson.build:12:  test('Validate desktop file', desktop_utils, args: [desktop_file])
origin/main:data/meson.build:25:  test('Validate appstream file',
origin/main:data/meson.build:38:  test('Validate schema file',
```

`ninja test` runs them and a red one fails the build. They are tests by the
only definition that matters here.

The port's root `TEST_PARITY.md` reports **0 upstream tests, 0 gaps, "parity
is therefore 0/0 and is met trivially"**, on this evidence:

> `grep -rn 'test' meson.build src/meson.build` → nothing

The grep is true for those two files and the conclusion is false, because it
never looked at the third `meson.build`. The `.reports/` copy of this document
corrected the count to 3 on 2026-11-02 at 09:27. The root ledger was rewritten
at 11:54, after that correction, and still carries the 0. See
`accountability-ensurance.md`, Finding 2.

## Suite: `data/meson.build` — 3 tests, 0 ported

| # | Upstream test | What it asserts | Port | Status |
|---|---|---|---|---|
| 1 | `Validate desktop file` (`data/meson.build:12`) | the merged `.desktop` passes `desktop-file-validate` | — | **GAP** |
| 2 | `Validate appstream file` (`data/meson.build:25`) | the merged metainfo passes `appstreamcli validate --no-net --explain` | — | **GAP** |
| 3 | `Validate schema file` (`data/meson.build:38`) | `data/*.gschema.xml` passes `glib-compile-schemas --strict --dry-run` | — | **GAP** |

All three inputs exist in the port and all three are installed by the flake.
Nothing validates any of them:

```
$ grep -rniE 'desktop-file-validate|appstreamcli|glib-compile-schemas' \
      Rakefile flake.nix .gitlab-ci.yml spec/ test/ .github/ nix/
flake.nix:235:  ${pkgs.glib.dev}/bin/glib-compile-schemas $out/share/glib-2.0/schemas
```

That one line compiles the installed schema. It is not `--strict --dry-run`,
it runs on the output rather than the source, and it does not fail the build
on a warning.

### What each gap costs

1. **Desktop entry.** A malformed `.desktop` is silently ignored by GNOME
   Shell: the app vanishes from the launcher, `Exec=paper-clip %U` never
   receives a file, and the *New Window* desktop action disappears. The port
   has already changed both `Exec=` lines and **added a `Comment=` key**
   upstream does not have — three edits to the exact file this test exists to
   check, none of them checked.
2. **AppStream metainfo.** An invalid metainfo means no GNOME Software entry
   and no screenshots. `appstreamcli` is also the only thing that would notice
   that the port ships no `data/screenshots/` of its own and cites four
   absolute `raw.githubusercontent.com` URLs into *upstream's* repository.
3. **GSettings schema.** A schema that fails `--strict` cannot be compiled
   into the system `gschemas.compiled`, and GLib treats a missing schema as
   fatal — the app aborts on startup the moment anything reads its settings.
   The port has edited this file too, changing `gettext-domain` from
   `pdf_metadata_editor` to `pdf-metadata-editor`.

### Closing them

Three one-line commands, each gated on the tool being present exactly as
upstream gates them on `find_program(..., required: false)`:

```
desktop-file-validate <merged .desktop>
appstreamcli validate --no-net --explain <merged metainfo>
glib-compile-schemas --strict --dry-run data
```

The merged artifacts exist only inside the Nix build, so the natural homes are
a `checkPhase` in `flake.nix`, or a `rake test:data` that runs
`msgfmt --desktop` / `msgfmt --xml` into a temp directory first and then
validates. Either way the three rows close together.

## Extra — the port's own suites

Outside the 3/3 count, because upstream owes none of it.

### `spec/` — 134 examples, 0 failures

| File | Examples | Covers |
|---|---:|---|
| `spec/paper_clip/document_spec.rb` | 41 | PDF date parsing, the `$TMPDIR/copies` copy, the Info dictionary, keywords, `n_pages`, XMP detection, the incremental-update writer, `/Prev` chaining, string escaping |
| `spec/paper_clip/pdf_crypt_spec.rb` | 35 | the standard security handler, RC4-40/128 and AES-128/256 against four fixture PDFs |
| `spec/paper_clip/xmp_packet_spec.rb` | 17 | packet rewriting, date properties, `dc:title` localised text, deletion |
| `spec/paper_clip/pdf_strings_spec.rb` | 19 | the layout / duplex / subtype / viewer-preference / permission tables |
| `spec/paper_clip/document_manager_spec.rb` | 8 | the dirty flag, document replacement, the stale-document identity check |
| `spec/paper_clip/translations_spec.rb` | 10 | the text domain, `_`, `N_`, `p_`, and a child process with `LANGUAGE` set |

### `test/drive_paper_clip.rb` — 278 checks, 99 steps, 18 screenshots

The harness builds the real application under `xvfb-run`, opens the real
windows and dialogs, loads real PDFs off disk including a genuinely AES-128
encrypted one, and asserts the observable result of each interaction. Every
file under `lib/paper_clip/` is reached. It is the reason
`component-parity.md` can report four axes instead of two, and it found two
port bugs that `ruby -c`, `require` and 134 green specs all passed
(`.reports/drive-run.md`).

### What the Extra suites do not cover

Not upstream-owed, so not in the 3/3 count — but these are the places where a
green verdict is thinner than it reads, and two of them are being reported as
driven when they are not.

1. **`Thumbnailer#load_scaled` is unreachable.** The branch fires at
   `350² × 2.5 = 306,250` pixels; every fixture page is `200 × 200 = 40,000`.
   `write_to_png`, the scale-step loop, `from_file_at_size`, `ExportError` and
   `CacheError` are never entered by anything in the repository.
   `COMPONENT_PARITY.md:216` nevertheless reads *"parity. Driven: the cache
   file appears in `$TMPDIR/thumbnails`"*. See
   `accountability-ensurance.md`, Finding 1.
2. **The thumbnail is only rendered from a page with no `/Contents`.** A
   renderer that drew nothing would pass all 278 checks.
3. **`win.open-with` is asserted enabled and never launched.**
   `Gtk::FileLauncher#launch` is asynchronous and opens a chooser the harness
   cannot answer, so the *Open With* flow — one of the three document actions
   — has never run end to end.
4. **`Gtk::FileDialog`** open and save-as choosers, for the same reason; the
   harness names this and drives every branch around them instead.
5. **No validation of `data/`** — which is gaps 1–3 above, restated from the
   port's side.

## Rules observed

- The upstream census was re-derived from the build files, not inherited. That
  is how the count is 3 and not 0.
- No gap was lowered, merged or marked `n/a`.
- Everything the port wrote is under **Extra**, outside the 3/3 count.
- `134 examples, 0 failures` and `278 of 278 checks passed` are the output of
  commands run for this audit, quoted as numbers rather than as adjectives.
- Where the port's own documents claim coverage that no executable artifact
  provides, this document says so rather than repeating the claim.
