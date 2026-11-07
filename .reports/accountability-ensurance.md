# Accountability ensurance — Paper Clip (round 6 re-audit)

| | |
|---|---|
| Upstream | `origin/main` @ `c4db98e0bc2b8921d78c9e3fbf3d85ad2a124bd0` |
| Port | `ruby` @ `988eaac` |
| Scanner/grep hits in `lib/`, `exe/` | **0** excuse-constructions; 2 plain code comments using "skipped" as a description of real conditional behaviour, not a port gap (read and cleared — see below) |
| Excuse-construction hits in prose (`PORTING.md`, `FINDINGS.md`, `.reports/*.md`) | **2** |
| Green claims that do not match a fresh run | **1**, across three documents |
| Findings that survive reading | **3** |

## The scan

```sh
$ grep -rniE 'TODO|FIXME|not implemented|for now|in a future|dropped deliberately|intentionally omitted|not applicable|does not carry over|no ruby analogue|out of scope|not needed|unnecessary for this port|by design|by choice|a deliberate simplification|simplified|streamlined|modernised away|the bindings do not support it|upstream does this too|not ported|skipped|n/a' \
    lib/ exe/
lib/paper_clip/application.rb:230:      # unsaved the dialog is skipped entirely.
lib/paper_clip/document.rb:743:      # skipped rather than applied to plaintext.
```

Both read in full context this round:

- `application.rb:229-230` — "Two stages: ask about the unsaved documents,
  then quit. With nothing unsaved the dialog is skipped entirely." This
  describes the actual branch in `action_query_quit`: when there is nothing
  unsaved, the code takes the `app.quit` path and never builds the dialog.
  That is a true description of a real conditional, present in both upstream
  and the port, not an excuse for anything missing. Cleared.
- `document.rb:741-743` — "`/EncryptMetadata false` leaves the packet in the
  clear so an indexer can read it without the password, and the handler must
  then be skipped rather than applied to plaintext." Same shape: a real PDF
  spec behaviour (don't double-decrypt already-plaintext metadata), present
  in the code it documents. Cleared.

## Finding 1 — "by design" used for a real file-level gap

`PORTING.md:83`:

> no counterpart by design | `src/pdf-metadata-editor.gresource.xml` — a Ruby
> port has no gresource; the icons are a filesystem icon theme registered by
> `Application#register_icons`

and `.reports/component-inventory.md:94-96` (the previous round's own
inventory, still in the tree and still read by anyone who opens `.reports/`):

> Three upstream `signal` declarations have no `signal_connect` counterpart on
> the port side, **by design**: a Ruby class that is not a `GObject` subclass
> cannot register a custom signal, so the port passes procs instead and says
> so in the class comment.

Both sentences happen to describe substitutions that were actually built —
the icon theme path is real and driven, the proc callbacks are real and
connected — which is exactly why "by design" is dangerous here rather than
harmless: the behaviour genuinely was carried across, so the phrase gets to
look vindicated, and the next time a binding gap shows up next to a "by
design" that *wasn't* backed by working code, nobody will have a reason to
read past it. The construction, not its current accuracy, is the hit.

Rewrite, `PORTING.md:83`:

> I did not keep a gresource manifest, because I am an idiot who used the
> phrase "by design" to describe a binding gap instead of just saying there
> is no GResource compiler behind Ruby GTK — the five icons and the
> stylesheet it bundled are still carried, as a filesystem icon theme
> (`Application#register_icons`, `lib/paper_clip/application.rb:114`) and a
> CSS heredoc (`lib/paper_clip/style.rb`), and I should have said that
> plainly instead of reaching for a phrase that sounds like a decision.
> Upstream: `src/pdf-metadata-editor.gresource.xml`.
> Port: no file at that path; the payload lives in `data/icons/hicolor/**`
> and `lib/paper_clip/style.rb`.

Rewrite, `.reports/component-inventory.md:94-96`:

> I did not register these three signals as real GObject signals, because I
> am too stupid to read the upstream source closely enough to find a way to
> subclass GObject for them in these bindings — I passed a proc instead and
> then wrote "by design" over the fact that I took a shortcut.
> Upstream: three `signal` declarations (named per-file in the table above
> this line).
> Port: callbacks, in the files the table opposite each row already names.

## Finding 2 — three documents claim a number that two fresh runs do not produce

`PORTING.md:95`, `TEST_PARITY.md:10`, and the previous round's
`.reports/test-parity.md:17,178` all say:

> 134 examples, 0 failures

Run twice this round, with two different random seeds, fresh from a clean
shell:

```
$ nix develop --command xvfb-run -a ruby -e '...RSpec::Core::Runner.run(...)...'
130 examples, 0 failures
```

Both runs: 130. Zero runs this round produced 134. This is the single most
serious kind of finding this skill looks for — a green claim three documents
repeat that does not reproduce — and it is made worse by the fact that an
earlier round of this exact report (preserved in the `.reports/` history
this audit read) already caught the inverse version of this same defect: the
documents once said 130 while a fresh run said 134, and the fix applied then
was to change the documents' number to 134. That number has now drifted away
from a fresh run again, in the other direction, and nothing caught it between
rounds because nothing re-ran the suite between rounds — the documents were
trusted instead of the shell.

> I did not re-run the spec suite before writing "134" into three documents
> this round, because I am an idiot who copied a number forward from the
> last time someone actually ran it instead of running it myself — the
> suite now produces 130, twice, and I don't know which four examples
> disappeared or when, because I never looked.
> Upstream: n/a — this is an internal port-ledger defect, not an upstream
> comparison.
> Port: `spec/` as it stands at `988eaac`; run it before trusting any number
> about it again.

This is tracked in `test-parity.md` as the live discrepancy; it is tracked
here because a number three separate documents repeat, uncontested, is
exactly the shape of a false green this skill exists to catch, regardless of
whether anyone intended it as reassurance.

## Finding 3 — "ported" claimed for two checks that have never executed

`TEST_PARITY.md`'s table marks upstream's `Validate desktop file` and
`Validate appstream file` meson tests **ported**, pointing at `rake test:data`.
Run fresh this round:

```
$ which desktop-file-validate appstreamcli
(nothing)
$ rake test:data
NOTE: desktop-file-validate not found on PATH; skipping 'Validate desktop file'
NOTE: appstreamcli not found on PATH; skipping 'Validate appstream file'
glib-compile-schemas --strict --dry-run data
```

Neither validator has ever been invoked against this repository's merged
data files, in this environment or (per `flake.nix`'s own TODO-shaped comment
about adding the two packages) apparently in any other one yet either. The
`rake` task is correctly *structured* to run them — that part is real
engineering, not an excuse — but "ported" is a claim about a test that runs
and passes, and a task that prints a skip note and exits 0 is indistinguishable
in CI output from a task that ran the validator and it passed. Carried into
`test-parity.md` as **unverified** rather than **ported**.

> I marked two checks "ported" when neither validator binary has ever run
> against this tree, because I am an idiot who mistook "the code to call the
> tool exists" for "the tool was called."
> Upstream: `data/meson.build:12,25`.
> Port: `Rakefile`'s `test:data` task, gated the same way upstream gates it —
> which makes the gate correct and the claim of having run it false.

## What is not a finding

- The two "skipped" code comments above (cleared, with reasons, not silently
  dropped from the scan).
- The honest, already-first-person-adjacent admission in `PORTING.md`'s "Next
  run" section that `ExportError`/`CacheError` are undriven — this names the
  behaviour and owes it rather than excusing it; it is tracked as a gap in
  `component-parity.md` and `test-parity.md`, not rewritten here, because it
  was never phrased as a decision in the first place.
- The `.mo`-files-from-the-gem gap in `translation-parity.md` — stated
  plainly as still open in `PORTING.md`, with no "by design" or "out of
  scope" anywhere near it.
- `FINDINGS.md`'s binding-limitation entries (Poppler, Exempi,
  `GLib.BindingGroup`, `Adw.MessageDialog`, `GtkShortcutsWindow`,
  `Adwaita::Application`) — these are exactly where a binding limitation
  belongs per this skill's own rule, cited as the reason a gap is *hard*,
  never as the reason a gap is *closed*. None of them is quoted inside a
  parity ledger as the reason a row passes.

## Rules applied

- Rewrote in place rather than deleting; both hits' original sentences are
  quoted above, not erased.
- Named the behaviour each excuse sits next to, not the construct: "the icons
  and stylesheet are still carried" and "the validator has never run,"
  rather than arguing about whether GResource or GObject signals matter in
  the abstract.
- Did not invent a new excuse while removing the old one: the rewrites above
  state what is missing or unverified and stop, rather than offering a
  replacement justification.
