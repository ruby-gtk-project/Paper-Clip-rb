# Test parity — Paper Clip (round 6 re-audit)

| | |
|---|---|
| Upstream | `origin/main` @ `c4db98e0bc2b8921d78c9e3fbf3d85ad2a124bd0` |
| Port | `ruby` @ `988eaac` |
| Upstream unit tests (`g_test_add_func` etc.) | **0** — no `test/`/`tests/` directory, no `Test.add_func`, nothing |
| Upstream `meson test` targets | **3**, all in `data/meson.build` |
| Ported (of those 3) | **3 named**, but **1 of 3 actually executed and passing on this machine**; 2 are gated-skip for a missing tool, never run here |
| Port's own suite, run fresh this round | **130 examples, 0 failures** |
| Port's own suite, as every committed document currently claims | **134 examples, 0 failures** |
| Drive harness, run fresh this round | **283 of 283 checks passed, `DRIVE OK`** |

## Upstream has no unit-test suite, and `meson test` is not nothing

Confirmed again this round, same as the prior ledger: no `g_test_add_func`,
no Python/GJS test runner, no `test/` directory anywhere in `origin/main`.
But `data/meson.build` registers three `test()` targets that `ninja test`
actually runs and that fail the build when red:

```
$ git grep -n "test(" origin/main -- '*meson.build'
origin/main:data/meson.build:12:  test('Validate desktop file', desktop_utils, args: [desktop_file])
origin/main:data/meson.build:25:  test('Validate appstream file', ...)
origin/main:data/meson.build:38:  test('Validate schema file', ...)
```

| # | Upstream test | Purpose | Port | State, verified this round |
|---|---|---|---|---|
| 1 | `Validate desktop file` | the merged `.desktop` passes `desktop-file-validate` | `rake test:data` | **gap, unverified**: `which desktop-file-validate` finds nothing in this devShell; `rake test:data` prints `NOTE: desktop-file-validate not found on PATH; skipping` and exits 0 regardless. It has never actually run the validator in this sandbox or, as far as this audit can tell, anywhere committed to this repo. |
| 2 | `Validate appstream file` | the merged metainfo passes `appstreamcli validate --no-net --explain` | `rake test:data` | **gap, unverified** — same story: `which appstreamcli` finds nothing, same skip-and-exit-0. |
| 3 | `Validate schema file` | `data/*.gschema.xml` passes `glib-compile-schemas --strict --dry-run` | `rake test:data` | **ported, and this one actually ran**: `glib-compile-schemas` is on `PATH` in this devShell, the check executed for real, and it passed. |

This is a real distinction and the committed `TEST_PARITY.md` blurs it by
marking all three "ported"/"ported, runs". Marking rows 1 and 2 **ported**
when the validator binary has never been invoked, in this round or (per
`flake.nix`'s own comment admitting the two tools are not yet added to the
devShell) in any prior one either, is the gap this skill exists to catch: a
gated no-op that always exits 0 reads identically to a passing check in CI
output. Re-labelling: rows 1 and 2 are **unverified**, not **ported**, until
`desktop-file-utils` and `appstream` are in the devShell and the validators
have actually run once and printed a result.

## The port's own suite: a live discrepancy with every committed document

```
$ nix develop --command xvfb-run -a ruby -e \
  'require "rspec/core"; exit RSpec::Core::Runner.run(["--format","progress","--require","spec_helper","spec"])'
Randomized with seed 52499
..................................................................................................................................
Finished in 1.11 seconds (files took 6.72 seconds to load)
130 examples, 0 failures
```

Run twice this round with different random seeds; both runs report **130**,
not 134. `PORTING.md`, `TEST_PARITY.md` and the previous `.reports/test-parity.md`
all currently say **134 examples, 0 failures**. One of these numbers is wrong,
and it has been wrong in at least one direction before: an earlier round of
this same report (see `accountability-ensurance.md`'s Finding 5 history) once
caught the committed ledgers saying "130" when the live run was "134" after a
fixture round added examples. Now, after further rounds, the live run is back
to 130 while every committed document still says 134. Either four examples
were quietly removed since whichever round actually produced 134, or 134 was
never an accurate count of this tree to begin with — either way, **a specific,
checkable number in three load-bearing documents does not match what the
suite that those documents cite actually produces**, right now, run twice.

This matters past the four-example gap itself: the suite uses looped example
generation (`spec/paper_clip/pdf_crypt_spec.rb`'s `FIXTURES.each`,
`pdf_strings_spec.rb`'s bit-map `.each`, `document_spec.rb`'s `raw.each`), so
the true count is not a thing a reader can verify by `grep -c 'it "'` — it has
to be run. No committed document shows the seed or the seed-to-seed count
agreeing, which is the only way "134" could be re-verified without running it.
**This is reported as a gap in the ledger's own accuracy, not in the suite's
correctness** — 0 failures is confirmed true at either count.

## Drive harness

```
$ nix develop --command xvfb-run -a ruby test/drive_paper_clip.rb
...
283 of 283 checks passed
DRIVE OK
```

Run fresh this round, matches the committed number exactly. This is the one
runtime number in the whole audit that reproduced on the nose.

## Behaviour still owed (carried from `component-parity.md`)

| Upstream property | Purpose | Port test/drive step | State |
|---|---|---|---|
| `Services/Thumbnailer`'s `ExportError` domain | a failed PNG write surfaces as a named error, not a crash or a silent blank | none | **gap** — no spec or drive step forces the write to fail |
| `Services/Thumbnailer`'s `CacheError` domain | a failed cache read-back surfaces the same way | none | **gap** — same, for the read-back |
| `DocumentView`'s `@loading` re-entrancy guard actually suppressing a write-back loop | editing a field while a document loads does not fire a spurious "dirty" edit back onto the model | none in `test/drive_paper_clip.rb` | **gap** — `@loading` exists and is read in `document_view.rb`, but nothing drives the race it guards against |
| `DateRow`'s `@syncing` guard | same shape, for the calendar/entry sync in the date picker | none | **gap** |
| `Window#proceed_with_state` | the save-or-discard flow actually blocks quitting until a real decision | none | **gap** — the method exists and is called from three sites in `window.rb`; none of the three is reached by a drive step that names it |

## Rules applied

- Did not accept "134, 0 failures" from the documents; ran the suite twice,
  fresh, and reported the number that printed.
- Did not accept "ported" for the two gated validator checks; ran `rake
  test:data` and read which branch actually executed versus which printed a
  skip note.
- Recorded the drive-harness-but-not-the-error-path gaps with the specific
  behaviour owed, not a construct name.
