# Component parity — Paper Clip (round 6 re-audit)

| | |
|---|---|
| Upstream | `origin/main` @ `c4db98e0bc2b8921d78c9e3fbf3d85ad2a124bd0` |
| Port | `ruby` @ `988eaac` |
| Units compared | 23 (per `PORTING.md`'s own file mapping, independently re-derived in `component-identification.md`) |
| Driven this round, fresh | `nix develop --command xvfb-run -a ruby test/drive_paper_clip.rb` → **283 of 283 checks passed, `DRIVE OK`**, exit 0 |
| Stylesheet | `src/style.css` vs `lib/paper_clip/style.rb`'s heredoc — **byte-identical rule bodies** (diffed directly this round) |
| Icons | upstream's 5 `gresource.xml` symbolic SVGs = the port's 5 files under `data/icons/hicolor/scalable/actions/`, registered via `Gtk::IconTheme#add_search_path` instead of a gresource path — a correspondence, not a gap |
| Open component-level gaps | **0 confirmed missing widgets/CSS/signals/actions** |
| Unverified branches (driven claim does not cover them) | **2** |

## What re-running the drive harness actually proved this round

`COMPONENT_PARITY.md` and `PORTING.md` both claim the whole app is driven,
283/283. Re-running it fresh (not trusting the committed number) reproduces
283/283, `DRIVE OK`, so **that specific claim holds** — unlike in rounds 1–2,
where this same report caught the ledger quoting numbers from a run that
never happened in the repository (see `accountability-ensurance.md`'s
history). This round's 283 is real: the output was captured live for this
audit, step by step, ending in the same two counts the committed docs show.

## Where the "driven" claim stops short

`PORTING.md`'s own "Next run" section says, about the PNG-cache branch the
drive harness exercises with `PdfFixtures.big`:

> `ExportError`/`CacheError` are still not driven, since nothing in the
> harness forces either write to fail.

That is an honest admission, not an excuse — it names the behaviour (what the
user sees when a thumbnail write fails) and says plainly it is unexercised.
It is still a **component parity gap**, because `Thumbnailer`'s error-domain
handling is part of the component: upstream's `Services/Thumbnailer.vala`
defines both error domains, and nothing anywhere — spec, drive step, or
otherwise — has ever forced either path to run. A branch no check exercises
is unverified, not done, independent of whether the admission is honest.

| Gap | Upstream | Port | What is missing |
|---|---|---|---|
| 1 | `src/Services/Thumbnailer.vala`'s `ExportError` domain | `lib/paper_clip/thumbnailer.rb` defines the same domain | No spec, no drive step, forces a PNG write to fail and asserts the error surfaces |
| 2 | same file's `CacheError` domain | same file | No spec, no drive step, forces the cache read-back to fail and asserts the error surfaces |

## Three-axis spot check on the units most recently touched

Re-checked by hand this round rather than carried from the ledger:

- **`document_thumbnail.rb` / `thumbnailer.rb`** (closed round 3, driven round
  5): `grep -n thumbnails test/drive_paper_clip.rb` now shows the harness
  reading back a PNG and checking a pixel darker than the backing rectangle —
  confirmed by reading `test/drive_paper_clip.rb`'s new block directly, not by
  trusting the prose. This closes the "driven but with nothing drawn" failure
  mode the previous round's audit caught here.
- **`about_dialog.rb`**: `PORTING.md`/`COMPONENT_PARITY.md` say the debug
  block prints a Poppler version and the port's own gem version in place of
  Exempi. Read `about_dialog.rb` directly: it does — `Poppler #{poppler_version}`
  and a line naming `XmpPacket`'s own version constant. The stale comment
  above it (claiming the port links neither Poppler nor Exempi) was rewritten
  in `988eaac`; re-read this round, it now matches the code beneath it.
- **`window.rb`**'s `proceed_with_state` and **`date_row.rb`**'s `@syncing`
  guard, named in `TEST_PARITY.md` as owed drive coverage: grepped for in
  `test/drive_paper_clip.rb` this round — neither name appears. The widgets
  exist and their signals are connected (component parity on the structural
  axes holds), but the specific re-entrancy guard upstream's `GLib.BindingGroup`
  replacement depends on has never been driven into firing. Recorded here
  because a connected signal is not a working signal (skill rule, Step 5) —
  carried into `test-parity.md` as the behaviour still owed.

## Rules applied

- Did not report parity from the drive harness total alone — spot-checked
  three specific units' source against the claim.
- Did not treat "driven" as a single yes/no: the PNG-cache *happy* path is
  driven; its two error domains are not, and both states are recorded
  separately rather than folded into one green row.
