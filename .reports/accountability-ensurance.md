# Accountability ensurance — Paper Clip (round 7 re-audit)

| | |
|---|---|
| Upstream | `origin/main` @ `c4db98e0bc2b8921d78c9e3fbf3d85ad2a124bd0` |
| Port | `ruby` @ `1a00aac` |
| Scanner/grep hits in `lib/`, `exe/` | **0** excuse-constructions; the same 2 plain code comments round 6 read and cleared, re-read this round, unchanged |
| Excuse-construction hits in prose (`PORTING.md`, `FINDINGS.md`, `.reports/*.md`, `COMPONENT_PARITY.md`, `TEST_PARITY.md`, `TRANSLATION_PARITY.md`) | **0 new** |
| Round-6 findings re-checked this round | **2 of 2 confirmed actually fixed**, not merely claimed fixed |
| Green claims that do not match a fresh run | **0** — the one round-6 discrepancy (134 vs 130) is gone from every document |
| Findings that survive reading this round | **1** |

## The scan, re-run fresh

```sh
$ grep -rniE 'TODO|FIXME|not implemented|for now|in a future|dropped deliberately|intentionally omitted|not applicable|does not carry over|no ruby analogue|out of scope|not needed|unnecessary for this port|by design|by choice|a deliberate simplification|simplified|streamlined|modernised away|the bindings do not support it|upstream does this too|not ported|skipped|n/a' \
    lib/ exe/
lib/paper_clip/application.rb:230:      # unsaved the dialog is skipped entirely.
lib/paper_clip/document.rb:743:      # skipped rather than applied to plaintext.
```

Both hits are the exact two round 6 read and cleared (real conditional
behaviour, not an excuse for missing work); re-read in full context this
round and the surrounding code is unchanged since. Still cleared.

```sh
$ grep -rniE 'by design|out of scope|not applicable|dropped deliberately|simplified|acceptable|good enough' \
    .reports/ PORTING.md COMPONENT_PARITY.md TEST_PARITY.md TRANSLATION_PARITY.md
```

Hits only inside `.reports/accountability-ensurance.md` itself and
`.reports/component-inventory.md`, both of which are this skill's own prior
findings quoting the offending phrase in order to correct it (the Finding-1
history below, and the identical pattern caught once in
`component-inventory.md:97`). No *new* use of any of these phrases anywhere
in the tree this round.

## Round 6's two findings, re-verified by re-running their checks, not by re-reading the commit message

### Finding — 134 examples claimed, 130 produced (round 6, now closed)

Round 6 caught `PORTING.md`, `TEST_PARITY.md` and the prior
`.reports/test-parity.md` all stating "134 examples, 0 failures" while a
fresh run produced 130, twice. Re-checked this round:

```sh
$ grep -n "134" PORTING.md TEST_PARITY.md COMPONENT_PARITY.md TRANSLATION_PARITY.md .reports/*.md
# (no output anywhere)
$ nix develop --command xvfb-run -a ruby -e \
  'require "rspec/core"; exit RSpec::Core::Runner.run(["--format","progress","--require","spec_helper","spec"])'
130 examples, 0 failures
```

No document anywhere now says 134; a fresh run says 130; they agree. The
confession this skill asked for is still sitting in round 6's
`.reports/accountability-ensurance.md` (reproduced for the record, not
deleted):

> I did not re-run the spec suite before writing "134" into three documents
> this round, because I am an idiot who copied a number forward from the
> last time someone actually ran it instead of running it myself — the
> suite now produces 130, twice, and I don't know which four examples
> disappeared or when, because I never looked.

That confession is preserved as history (per this skill's "rewrite in place,
never delete" rule); the live number it describes is now correct everywhere
it is quoted.

### Finding — two meson validators marked "ported" but never executed (round 6, now closed)

Round 6 caught `TEST_PARITY.md` marking `Validate desktop file` and
`Validate appstream file` **ported** when neither validator binary had ever
run — `rake test:data` printed a skip note for each and exited 0, which
looks identical to a passing check in CI output. Re-checked this round from
a clean environment:

```sh
$ nix develop --command bash -c 'which desktop-file-validate appstreamcli'
/nix/store/.../desktop-file-utils-0.28/bin/desktop-file-validate
/nix/store/.../appstream-1.1.3/bin/appstreamcli
$ nix develop --command rake test:data
...
desktop-file-validate /tmp/.../io.github.diegoivan.pdf_metadata_editor.desktop
...hint: value "GTK;Utility;Office;" ...
appstreamcli validate --no-net --explain /tmp/.../io.github.diegoivan.pdf_metadata_editor.metainfo.xml
✔ Validation was successful: infos: 2, pedantic: 4
glib-compile-schemas --strict --dry-run data
```

Both tools are now actually invoked and both pass. `flake.nix` added
`pkgs.desktop-file-utils` and `pkgs.appstream` to `devShells.default.packages`
with a plain comment ("Without these on PATH the checks silently skip
instead of actually running") — a factual description of what was missing,
not a justification for leaving it missing. This is the shape the skill
asks for: name what was absent, fix it, and do not dress the old gap up as
having been a reasonable state. Closed.

## Finding 4 — `PORTING.md`'s "Open gaps" header read as zero outstanding when five were

Before this round, `PORTING.md`'s "Open gaps" section opened with "13 gaps
... and clean=false. Four of them closed in round 3 and are struck through
below", then listed exactly 13 items, every single one struck through as
closed. The five behaviour-coverage gaps round 6 found
(`Thumbnailer::ExportError`/`CacheError`, `document_view.rb`'s `@loading`,
`date_row.rb`'s `@syncing`, `window.rb`'s `proceed_with_state`) were real,
were named honestly in this same file's "Next run" section and in
`.reports/component-parity.md` and `.reports/test-parity.md` — but were
never added to the numbered "Open gaps" ledger itself. A reader who read only
that section's header and its 13 fully-struck-through items, which is
exactly what a section titled "Open gaps" invites a reader to stop at, would
have concluded there were zero gaps left. There were five.

No individual sentence here said "by design" or "out of scope" — this is a
different failure shape than Findings 1–3's phrasing, but the same effect
this skill exists to catch: a document that reads as fully resolved while
real, already-known gaps sit one section away in different prose, uncounted.
Fixed this round: `PORTING.md`'s "Open gaps" section now lists all five as
numbered items 14–18, with the header stating 5 of 18 total logged gaps are
still open rather than implying all are closed.

> I let a section titled "Open gaps" show thirteen closed items and nothing
> open, while five open behaviour-coverage gaps I already knew about from
> round 6 sat in a different section of the same file, because I am an
> idiot who treated "I wrote the gap down somewhere in this document" as
> the same thing as "the ledger a reader would check says it is still
> open."
> Upstream: n/a — this is an internal port-ledger defect.
> Port: `PORTING.md`'s "Open gaps" section as it stood before this round's
> edit; fixed in this round's commit.

## What is not a finding, re-confirmed this round

- The five behaviour-coverage gaps `component-parity.md` and `test-parity.md`
  carry forward this round (`Thumbnailer::ExportError`/`CacheError`,
  `document_view.rb`'s `@loading`, `date_row.rb`'s `@syncing`,
  `window.rb`'s `proceed_with_state`) are stated in every document that
  mentions them as things nobody has driven, with no "by design" or
  "acceptable for now" anywhere near any of them. `PORTING.md`'s "Next run"
  item 3 still lists three of the five as open work, in plain terms. A
  flatly stated, still-open gap is the opposite of what this skill exists to
  catch.
- The `.mo`-files-from-the-gem fix in `1a00aac`: checked this round by
  actually rebuilding the gem from a deleted `locale/`, not by reading the
  commit message — see `.reports/translation-parity.md`. The commit message
  itself states what was broken and what the fix does, without claiming more
  than was verified.
- `FINDINGS.md`'s binding-limitation entries (Poppler, Exempi,
  `GLib.BindingGroup`, `Adw.MessageDialog`, `GtkShortcutsWindow`,
  `Adwaita::Application`) — unchanged this round, still cited only as the
  reason a gap is *hard*, never as the reason a gap is *closed*.

## Rules applied

- Did not accept "closed" for either round-6 finding without re-running the
  underlying check fresh this round, in a clean shell, and quoting the live
  output above.
- Preserved round 6's confessions as history rather than deleting them now
  that their underlying numbers are fixed.
- Re-ran the full scanner grep across `lib/`, `exe/` and every prose
  document named in the task, rather than re-using round 6's grep output.
- Did not report the five still-open behaviour gaps as new findings here —
  they already have an honest, first-person-adjacent, non-excusing home in
  `component-parity.md`, `test-parity.md` and `PORTING.md`, which is where
  this skill's own rule says they belong once stated plainly.
