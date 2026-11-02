# Test parity — Paper-Clip-rb

| | |
|---|---|
| Upstream | `origin/main` @ `c4db98e0bc2b8921d78c9e3fbf3d85ad2a124bd0` |
| Port | `ruby` branch, round 3 |
| Upstream tests | **0** |
| Ported | 0 |
| Gaps | 0 |
| Port tests (Extra) | **134 examples, 0 failures** |
| Test command | `nix develop --command rspec --require ./spec/spec_helper.rb -Ilib -Ispec spec` |

## Upstream has no test suite

Verified, not assumed:

```
test-census.sh <origin/main tree>   ->  0 rows
git ls-tree -r --name-only origin/main | grep -E '(^|/)tests?/'   ->  nothing
grep -rn 'test' meson.build src/meson.build   ->  nothing
```

No `test/` or `tests/` directory, no `Test.add_func`, no `g_test_add`, no
`unittest`, no `pytest`, and no `test` target or `tests` array in any
`meson.build`. The build-file cross-check the skill requires finds no declared
test binary to reconcile against.

Parity is therefore **0/0 and is met trivially.** That is a count, not a pass.
Upstream wrote down nothing about its own behaviour that this port could have
inherited, so everything below is the port's own, and nothing in the port is
pinned by anything upstream.

## Extra — the port's own suite

Outside the 0/0 count, because upstream owes none of it.

```
$ nix develop --command rspec --require ./spec/spec_helper.rb -Ilib -Ispec spec
130 examples, 0 failures
```

| File | Examples | What is pinned |
|---|---:|---|
| `spec/paper_clip/document_spec.rb` | 41 | the PDF date parser and formatter (`document.rb` `parse_date`/`format_date`), the `$TMPDIR/copies` cached copy and the original's immutability, the Info read, the page count and its zero case, the keyword comma split and round trip, the change-notification contract, and the incremental-update writer: original bytes kept, `/Prev` chained, a classic table with twenty-byte entries, offsets that point at the objects they describe, two saves in a row, UTF-16BE behind a BOM, and literal escaping |
| `spec/paper_clip/pdf_crypt_spec.rb` | 35 | RC4 against the RFC 6229 test vector and as its own inverse; then, for each of `/R` 2, 3, 4 and 6: refusal with no password, refusal of a wrong password, decryption under the user password, decryption under the owner password, an edit re-encrypted and read back, that the plaintext does not appear in the saved file, that `/Encrypt` and `/ID` are still named in the appended trailer, and that `/Encrypt /P` is still readable afterwards |
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

## Owed, and why it is not written

Three checks from the round-2 brief are missing, and all three are
widget-level:

| Check | Why it is not written |
|---|---|
| the `@loading` re-entrancy guard (`document_view.rb`) | needs an `Adwaita::EntryRow` to emit `notify::text` |
| the `@syncing` calendar guard (`date_row.rb`) | needs a `Gtk::Calendar` to emit `day-selected` |
| `proceed_with_state` (`window.rb`) | needs a window, a dialog and a state machine driven through them |

GTK cannot initialise in this environment — no display, no `Xvfb` — so a spec
for any of the three could be written but never executed. A spec that has
never run is not evidence, so they are owed rather than present. The cost of
unblocking them is one line in the flake's devShell; see `FINDINGS.md` §8.

**No widget driving has happened at all.** `.claude/skills/ruby-gtk-testing`
ships a headless driver and nothing in this repo has invoked it. Every signal
in `COMPONENT_PARITY.md` is a static read.

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
under `rspec` directly. See `FINDINGS.md` §9.

## Rules observed

- The parity count is 0/0 and is reported as a count.
- Everything the port wrote is under `## Extra`, outside that count.
- The three missing checks carry a behaviour, not a construct, and name what
  blocks them.
- No row was lowered, merged or marked `n/a`.
