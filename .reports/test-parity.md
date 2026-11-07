# Test parity — Paper Clip (round 8 audit)

| | |
|---|---|
| Upstream | `origin/main` @ `c4db98e0bc2b8921d78c9e3fbf3d85ad2a124bd0` |
| Port | `ruby` @ `60ffe4d` |
| Upstream unit tests (`g_test_add_func` etc.) | **0** — no `test/`/`tests/` directory, no `Test.add_func`, nothing |
| Upstream `meson test` targets | **3**, all in `data/meson.build` |
| Ported (of those 3) | **3 named, 3 actually executed and passing**, re-verified fresh this round |
| Port's own suite, run fresh this round | **134 examples, 0 failures** |
| Port's own suite, as `PORTING.md`/`COMPONENT_PARITY.md`/`TEST_PARITY.md` now claim | **134 examples, 0 failures** — matches |
| Drive harness, run fresh this round | **318 of 318 checks passed, `DRIVE OK`** |

## What changed since round 7's audit, and whether the new claim holds

Round 7 left five behaviour-coverage gaps open: `Thumbnailer::ExportError`,
`Thumbnailer::CacheError`, `DocumentView`'s `@loading` guard, `DateRow`'s
`@syncing` guard, and `Window#proceed_with_state`'s Discard/empty-selection
call sites. One commit landed since, `60ffe4d`, claiming to close all five
and to raise the drive total from 283 to 318. Re-tested this round from a
clean shell rather than trusting the commit message:

```sh
$ nix develop --command xvfb-run -a ruby test/drive_paper_clip.rb
... (full run)
318 of 318 checks passed
DRIVE OK
$ nix develop --command xvfb-run -a ruby -e \
  'require "rspec/core"; exit RSpec::Core::Runner.run(["--format","progress","--require","spec_helper","spec"])'
Randomized with seed 32743
134 examples, 0 failures
$ nix develop --command rake test:data
desktop-file-validate ...  (1 hint, upstream's own multi-category Categories key, exit 0)
appstreamcli validate --no-net --explain ...  Validation was successful: infos: 2, pedantic: 4
glib-compile-schemas --strict --dry-run data  (exit 0)
```

All three numbers reproduce exactly what `60ffe4d`'s commit message and
`PORTING.md` claim: 318/318, `DRIVE OK`, 134/134, and all three meson
validators actually invoking their binary and exiting clean, not
gated-skip.

| # | Upstream test | Port | State, verified this round |
|---|---|---|---|
| 1 | `Validate desktop file` | `rake test:data` | **ported, runs** |
| 2 | `Validate appstream file` | `rake test:data` | **ported, runs** |
| 3 | `Validate schema file` | `rake test:data` | **ported, runs** |

## The five behaviour-coverage gaps round 6 and round 7 both carried forward — re-checked by name, not assumed closed

```sh
$ grep -rn "proceed_with_state\|@syncing\|ExportError\|CacheError" test/drive_paper_clip.rb | wc -l
```

Each name now appears in `test/drive_paper_clip.rb`'s new blocks (added by
`60ffe4d`), and each block was read, not just grepped for presence:

| Upstream property | Purpose | Port test/drive step | State |
|---|---|---|---|
| `Services/Thumbnailer`'s `ExportError` domain | a failed PNG write surfaces as a named error, not a crash or a silent blank | `test/drive_paper_clip.rb`, "a PNG write that cannot land raises Thumbnailer::ExportError" | **closed** — forces a real write failure (missing parent directory) and asserts the error, its ancestry, and its message |
| `Services/Thumbnailer`'s `CacheError` domain | a failed cache read-back surfaces the same way | same file, "a cache directory that cannot be created raises Thumbnailer::CacheError" | **closed** — forces `Dir.tmpdir` onto a path that is a plain file, asserts the error, and asserts `Dir.tmpdir` is restored afterward |
| `DocumentView`'s `@loading` guard suppressing a write-back loop | editing a field while a document loads does not fire a spurious "dirty" edit back onto the model | same file, "forcing @loading and editing a row proves the write-back guard" | **closed** — forces `@loading` true, edits a row to a value the document does not have, asserts the document and dirty flag did not follow, then proves the real path still works once released |
| `DateRow`'s `@syncing` guard | same shape, for the calendar/entry sync in the date picker | same file, "setting a date from outside the calendar does not re-enter on_change" | **closed** — spies on `on_change`, assigns a date externally (which fires `day-selected` on its own), asserts the spy was not re-entered, then picks a day for real and asserts it was, exactly once |
| `Window#proceed_with_state`'s Discard and empty-selection-Save sites | the save-or-discard flow actually blocks quitting until a real decision, on all three call sites | same file, "a fresh window opens for the Discard path" / "...for the empty-selection Save path" | **closed** — each opens its own window (so neither close risks the application's last window and this run), edits it, blocks the close, answers the dialog, and confirms the edit never reached the file |

**This round's finding: all five are genuinely closed, not merely marked
closed.** The distinguishing question this skill asks — "does the new check
force the specific failure/race/decision, or does it only run the happy
path near it?" — was checked for each row above by reading the block, and
each one answers yes.

## A real bug the new coverage surfaced

Forcing `ExportError` found that `Thumbnailer#export`'s original
`rescue Cairo::Error, SystemCallError` did not catch the actual failure
class (`Cairo::WriteError`, a Ruby `IOError`). `lib/paper_clip/thumbnailer.rb`
now also rescues `IOError`, confirmed by reading the diff directly. This is
exactly the value this skill exists to produce: an untested branch that
looked fine by inspection turned out to be wrong once actually driven.

## Rules applied

- Did not accept "closed" for any of the five round-6/7 gaps from the
  commit message; re-read each new drive block and re-ran the full suite
  fresh in this session.
- Re-ran `rake test:data` fresh rather than trusting the prior round's
  "all three tools on PATH" finding, since a devShell change could in
  principle regress it (it did not: `flake.nix` was not touched by `60ffe4d`).
- Quoted live output for every number in this report rather than any
  number already committed to `PORTING.md` or `TEST_PARITY.md`.
