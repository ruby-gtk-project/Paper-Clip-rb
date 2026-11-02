# Test parity — Paper Clip

| | |
|---|---|
| Upstream | `origin/main` @ `c4db98e0bc2b8921d78c9e3fbf3d85ad2a124bd0` |
| Port | `ruby` @ `6d05c88af0f4ad6db5fbd16c88b1d4d9a93d632c` |
| Upstream tests | **0** |
| Ported | 0 |
| Gaps | 0 |
| Port tests | **0** |
| Test command | `rake spec` — **does not run**, see below |

## Upstream has no test suite

Verified, not assumed:

```
test-census.sh <origin/main tree>   ->  0 rows
git ls-tree -r --name-only origin/main | grep -E '(^|/)tests?/'   ->  nothing
grep -rn 'test' meson.build src/meson.build   ->  nothing
```

No `test/` or `tests/` directory, no `Test.add_func`, no `g_test_add`, no
`#[test]`, no `unittest`, no `pytest`, no Jasmine `it(...)`, and no `test`
target or `tests` array in any `meson.build`. The build file cross-check the
skill requires finds no declared test binary to reconcile against.

Parity is therefore **0/0 and is met trivially.**

**The port inherits no safety net.** Upstream wrote down nothing about its own
behaviour that this port could have inherited: not the PDF date parser, not
the keyword comma round-trip, not the permission bit mapping, not the
`/Encrypt` path, not one of the 29 enum-to-string tables. Every behaviour in
`.reports/component-parity.md` was read out of source by eye, by me, once.
Leaving that implied is how a 0/0 report gets read as a pass, so it is stated
here: nothing in this port is pinned by anything.

## What the port has instead: nothing, on a harness that is broken

The census on the port side is also empty:

```
test-census.sh .   ->  0 rows
find spec -type f  ->  spec/README.md, spec/spec_helper.rb
```

There is no `## Extra` section to write, because there is nothing to put in
it. The `ruby` branch carries 3,147 lines of `lib/` and `exe/` and zero
assertions over any of it.

Worse, the harness cannot start. `spec/spec_helper.rb:28` is:

```ruby
require "paper/clip/rb"
```

and that file does not exist — `lib/paper/clip/` contains only `rb/version.rb`.
Confirmed:

```
$ ruby -Ilib -e 'require "paper/clip/rb"'
cannot load such file -- paper/clip/rb
Did you mean?  paper/clip/rb/version
```

So `rake spec` cannot load its own helper, and the fourth proof condition the
skill lists — "the port's suite passes under its own test target" — is not
merely unmet, it is unreachable. The scaffold was committed
(`8bb24f4 Sync the scaffold from port-scaffold`) and never once run against
this gem's actual entry point, which is `lib/paper_clip.rb`.

## Gaps

| # | Gap | Behaviour still owed |
|---|---|---|
| 1 | `lib/paper/clip/rb.rb` does not exist, so `spec/spec_helper.rb:28` raises `LoadError` and `rake spec` cannot run | A developer who types the project's own documented test command gets a crash instead of a result |
| 2 | Zero checks over 3,147 lines of `lib/` | Nothing pins the PDF date parser (`document.rb:76-90`), the keyword comma round-trip, the `/Encrypt /P` bit mapping (`pdf_strings.rb:70-79`), the incremental-update writer (`document.rb` `save_async`), the `@loading` re-entrancy guard (`document_view.rb:185`), the `@syncing` calendar guard (`date_row.rb:122`), or `proceed_with_state` (`window.rb:447`) — the state machine that decides whether a user's unsaved edits survive a close |
| 3 | No widget driving at all | `.claude/skills/ruby-gtk-testing` ships a headless driver and `scripts/gtk_driver.rb`; nothing in this repo has ever invoked it. Every signal in `.reports/component-parity.md` is static-read, so a handler wired to an empty method passes every check that exists |

Rows 1-3 are not upstream parity rows — upstream owes none. They are the
port's own debt, and they are listed here because a reader of a 0/0 ledger
must not walk away thinking the testing question is closed.

## Rules observed

- The count is 0/0. It is not an adjective and it is not a pass.
- Gaps 1-3 carry a behaviour, not a construct.
- No row was lowered, merged or marked `n/a`.
