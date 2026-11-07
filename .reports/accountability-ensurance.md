# Accountability ensurance — Paper Clip (round 8 audit)

| | |
|---|---|
| Upstream | `origin/main` @ `c4db98e0bc2b8921d78c9e3fbf3d85ad2a124bd0` |
| Port | `ruby` @ `60ffe4d` |
| Scanner hits in `lib/`, `exe/` | **2** — the same 2 round 6/7 already read and cleared (real conditional-behaviour comments, not excuses), re-read this round, unchanged |
| Scanner hits in `test/`, `spec/` | **1** — a quoted upstream error string, not an excuse (see below) |
| Excuse-construction hits in prose (`PORTING.md`, `FINDINGS.md`, `.reports/*.md`, `COMPONENT_PARITY.md`, `TEST_PARITY.md`, `TRANSLATION_PARITY.md`) | **0 new** |
| Green claims checked against a fresh run this round | **318/318 drive, 134/134 spec, 3/3 meson validators, 87/87 `.pot` msgids, 18/18 `.po` byte-identical** — all reproduced live |
| Findings that survive reading this round | **0 new code/claim defects; 1 process note, below** |

## The scan, re-run fresh

```sh
$ grep -rniE 'TODO|FIXME|not implemented|for now|in a future|dropped deliberately|intentionally omitted|not applicable|does not carry over|no ruby analogue|out of scope|not needed|unnecessary for this port|by design|by choice|a deliberate simplification|simplified|streamlined|modernised away|the bindings do not support it|upstream does this too|not ported|skipped|n/a' \
    lib/ exe/
lib/paper_clip/application.rb:230:      # unsaved the dialog is skipped entirely.
lib/paper_clip/document.rb:743:      # skipped rather than applied to plaintext.
```

Both are the exact two lines round 6 read, cleared, and every round since
has re-read unchanged: real conditional behaviour ("when X, Y is skipped"),
not an excuse for missing work. Confirmed again this round by reading each
line's surrounding method, not just the grep context line.

```sh
$ grep -rniE 'TODO|FIXME|not implemented|for now|in a future' test/ spec/
test/drive_paper_clip.rb:1332:  # NotImplementedError out of gobject-introspection 4.3.9 ("TODO: in Ruby ->
```

This is a comment quoting the literal exception message `g_application_open`
raises (`drive-run.md`'s "Binding gaps" section documents the same string),
explaining why the harness drives the open path through a child process
instead. It names a real binding limitation it works around, with the
workaround present in the same file — not an admission that something was
left undone. Read in full context, not just the grep line.

```sh
$ grep -rniE 'by design|out of scope|not applicable|dropped deliberately|simplified|acceptable|good enough' \
    .reports/ PORTING.md COMPONENT_PARITY.md TEST_PARITY.md TRANSLATION_PARITY.md
```

Hits only inside `.reports/`'s own prior-round findings quoting the
offending phrase to correct it (same as every round since 6). No new use
anywhere in the tree this round.

## Round 7's one new finding (Finding 4) — checked whether it is still accurate

Round 7's `.reports/accountability-ensurance.md` found that `PORTING.md`'s
"Open gaps" section once read as fully resolved while five open gaps sat
elsewhere, and recorded the fix: the section was rewritten to list all five
as numbered items 14–18 with an accurate header count ("5 of 18 total
logged gaps are still open").

This round's commit, `60ffe4d`, closed all five of those items. Re-read
`PORTING.md`'s current "Open gaps" section rather than trusting that the
header updated correctly along with the five strike-throughs:

```sh
$ sed -n '/## Open gaps/,/## Blockers/p' PORTING.md | head -5
## Open gaps

18 gaps have been logged against this ledger across eight audit rounds; all
18 are now closed and struck through below rather than deleted, so the
ledger still shows what was owed and when.
```

The header says "all 18 are now closed", and all 18 numbered items below it
are in fact struck through (`grep -c '^[0-9]\+\. ~~' PORTING.md` → 18,
`grep -c '^[0-9]\+\. [^~]' PORTING.md` → 0). This round's version of
Finding 4's failure mode — a header claiming a state the body does not
match — is checked and does **not** recur: header and body agree, and both
match the live 318/318 run reproduced in `component-parity.md` and
`test-parity.md` this round.

## Process note — not a code or claim defect, recorded because the skill asks for it

Round 7's `.reports/*.md` files were committed at `c48a10c`, timestamped
before `60ffe4d` (the commit that actually closed the five gaps those
reports described as open). Between those two commits, `.reports/` sat
genuinely stale relative to the working tree for one commit's worth of
real work — not a false claim (each file states the exact commit hash it
describes, `1a00aac`, so a reader checking that line would not be misled),
but a reader trusting `.reports/`'s headline numbers without checking the
hash line would have seen "283/283, 5 open gaps" while `PORTING.md` in the
same tree already said "318/318, 0 open gaps". This round's five documents
are dated to the current HEAD (`60ffe4d`) and every number in them was
reproduced by a live run in this session, closing that staleness window.
No prior document is edited to hide that the window existed; this paragraph
is the record of it.

## What is not a finding, re-confirmed this round

- The five behaviour-coverage gaps round 6 and round 7 both carried
  (`Thumbnailer::ExportError`/`CacheError`, `document_view.rb`'s `@loading`,
  `date_row.rb`'s `@syncing`, `window.rb`'s `proceed_with_state`) are
  genuinely closed this round, not merely marked closed — see
  `test-parity.md`'s row-by-row check of what each new drive block actually
  asserts.
- The 87-vs-96 msgid-count split across documents (`.reports/` says 87,
  `COMPONENT_PARITY.md`/`TRANSLATION_PARITY.md` say 96) is not an
  unreconciled discrepancy — see `translation-parity.md`, which traces it
  to two different extraction scopes and names which side (upstream's own
  stale `.pot`) the gap actually sits on.
- `FINDINGS.md`'s binding-limitation entries (Poppler, Exempi,
  `GLib.BindingGroup`, `Adw.MessageDialog`, `GtkShortcutsWindow`,
  `Adwaita::Application`) — unchanged this round, still cited only as the
  reason a gap is *hard*, never as the reason a gap is *closed*.
- The round-6/round-7 confessions preserved in this file's history (the
  134-vs-130 example drift, the two gated-skip meson validators) are left
  in place rather than deleted now that their numbers are long since fixed
  and re-verified multiple rounds running.

## Rules applied

- Did not accept "closed" for the five round-6/7 gaps, or for Finding 4's
  fix, from a commit message or a prior round's prose — re-ran the live
  checks fresh this round and quoted their output above.
- Re-ran the full scanner grep across `lib/`, `exe/`, `test/` and `spec/`,
  and across every prose document named in the task, rather than re-using
  a prior round's grep output.
- Named the `.reports/`-vs-`PORTING.md` staleness window plainly, as a
  process fact with its cause and its close, rather than letting it pass
  unmentioned because the numbers underneath it are now green.
