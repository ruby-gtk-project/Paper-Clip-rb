# Test parity — Paper Clip

| | |
|---|---|
| Upstream | `origin/main` @ `c4db98e0bc2b8921d78c9e3fbf3d85ad2a124bd0` (2025-04-28) |
| Port | `ruby` branch, this audit |
| Upstream tests | **3** |
| Ported | **0** |
| Gaps | **3** |
| Port tests (Extra) | 130 examples, 0 failures |
| Test command | `nix develop --command rspec --no-color -f progress` |

## The upstream count is 3, not 0

The port's own `TEST_PARITY.md` reports **0** upstream tests and states:

> `grep -rn 'test' meson.build src/meson.build` → nothing
> … no `test` target or `tests` array in any `meson.build`.

The grep is true for those two files and the conclusion drawn from it is
false, because it never looked at the third `meson.build`:

```
$ git grep -n 'test(' origin/main -- '*meson.build'
origin/main:data/meson.build:12:  test('Validate desktop file', desktop_utils, args: [desktop_file])
origin/main:data/meson.build:25:  test('Validate appstream file',
origin/main:data/meson.build:38:  test('Validate schema file',
```

Upstream has no unit tests — there is no `test/`, no `Test.add_func`, no
`g_test_add`, no `pytest` — but it has three declared, named, `meson test`-runnable
tests. They are tests by the only definition that matters here: `ninja test`
runs them and a red one fails the build.

## Suite: `data/meson.build` (3 tests)

| # | Upstream test | What it asserts | Port test | Status |
|---|---|---|---|---|
| 1 | `Validate desktop file` (`data/meson.build:12`) | the merged `io.github.diegoivan.pdf_metadata_editor.desktop` passes `desktop-file-validate` | — | **GAP** |
| 2 | `Validate appstream file` (`data/meson.build:25`) | the merged metainfo passes `appstreamcli validate --no-net --explain` | — | **GAP** |
| 3 | `Validate schema file` (`data/meson.build:38`) | `data/*.gschema.xml` passes `glib-compile-schemas --strict --dry-run` | — | **GAP** |

All three files exist in the port (`data/io.github.diegoivan.pdf_metadata_editor.desktop.in`,
`.metainfo.xml.in`, `.gschema.xml`) and all three are produced by the flake's
`installPhase` (`flake.nix:181-208`). Nothing validates any of them:

```
$ grep -rniE 'desktop-file-validate|appstreamcli|--strict' Rakefile flake.nix .gitlab-ci.yml spec/
   (no matches)
```

`flake.nix:208` runs `glib-compile-schemas` on the output directory, which
compiles the schema but is not the `--strict --dry-run` check and does not
fail the build on a warning.

### What each gap costs

1. **Desktop entry.** A malformed `.desktop` is silently ignored by GNOME
   Shell: the app vanishes from the launcher, `Exec=paper-clip %U` never gets
   a file, and the *New Window* desktop action disappears. The port already
   changed two `Exec=` lines, which is exactly the edit this test exists to
   catch.
2. **AppStream metainfo.** An invalid metainfo means no entry in GNOME
   Software and no screenshots; `appstreamcli` is also the only thing checking
   that the four `<screenshot>` URLs still resolve.
3. **GSettings schema.** A schema that fails `--strict` cannot be compiled
   into the system `gschemas.compiled`; the app then aborts on startup the
   moment anything reads its settings, because GLib treats a missing schema as
   fatal.

### Closing them

Three `rake` tasks or three CI steps, each one line, each gated on the tool
being present exactly as upstream gates them on `find_program(..., required: false)`:

```
desktop-file-validate <merged .desktop>
appstreamcli validate --no-net --explain <merged metainfo>
glib-compile-schemas --strict --dry-run data
```

The merged artifacts only exist inside the Nix build, so the natural home is a
`checkPhase` in `flake.nix` or a `rake test:data` that runs `msgfmt --desktop`
/ `msgfmt --xml` into a temporary directory first.

## Extra — the port's own suite

Outside the 3/3 count, because upstream owes none of it.

```
$ nix develop --command rspec --no-color -f progress
130 examples, 0 failures   (1.56s)
```

| File | Examples (`it` strings) | Covers |
|---|---|---|
| `spec/paper_clip/document_spec.rb` | 41 | PDF date parsing, the `$TMPDIR/copies` copy, the Info dictionary, keywords, `n_pages`, XMP detection, the incremental-update writer, `/Prev` chaining, string escaping |
| `spec/paper_clip/pdf_crypt_spec.rb` | 35 | the standard security handler, RC4-40/128 and AES-128/256 against four fixture PDFs |
| `spec/paper_clip/xmp_packet_spec.rb` | 17 | packet rewriting, date properties, `dc:title` localised text, deletion |
| `spec/paper_clip/pdf_strings_spec.rb` | 19 | the layout / duplex / subtype / viewer-preference / permission tables |
| `spec/paper_clip/document_manager_spec.rb` | 8 | the dirty flag, document replacement, the stale-document identity check |
| `spec/paper_clip/translations_spec.rb` | 10 | the text domain, `_`, `N_`, `p_`, and a child process with `LANGUAGE` set |

### What the Extra suite does not cover

Not a parity gap — upstream tests none of it either — but it is the reason
`component-parity.md` Gap 5 matters:

- **No widget is constructed anywhere in `spec/`.** Zero `Adwaita::` or
  `Gtk::` objects. The suite deliberately loads only `lib/paper_clip/models.rb`,
  the toolkit-free half, because `require "gtk4"` raises `Gtk::InitError`
  without a display.
- Specifically unverified: `DocumentView`'s `@loading` write-back guard,
  `DateRow`'s `@syncing` guard, `KeywordList`'s incremental
  `on_items_changed`, and `Window#proceed_with_state`. Each is a guard flag
  whose whole purpose is to not fire — the failure mode is silent, and a
  reading cannot see it.

## Rules observed

- The upstream census was re-derived from the build files rather than
  inherited from the previous ledger, which is how the count moved from 0 to 3.
- No gap was lowered, merged or marked `n/a`.
- Everything the port wrote is under **Extra**, outside the 3/3 count.
- `130 examples, 0 failures` is reported as the number, not as an adjective.
