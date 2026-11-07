# Component parity — Paper Clip (round 8 audit)

| | |
|---|---|
| Upstream | `origin/main` @ `c4db98e0bc2b8921d78c9e3fbf3d85ad2a124bd0` |
| Port | `ruby` @ `60ffe4d` |
| Units compared | 29 (per `component-identification.md`, re-derived this round) |
| Driven this round, fresh | `nix develop --command xvfb-run -a ruby test/drive_paper_clip.rb` → **318 of 318 checks passed, `DRIVE OK`**, exit 0 |
| Stylesheet | `src/style.css` vs `lib/paper_clip/style.rb`'s heredoc — byte-identical rule bodies, unchanged since round 7 (`60ffe4d` did not touch `style.rb`) |
| Icons | upstream's 5 `gresource.xml` symbolic SVGs = the port's 5 files under `data/icons/hicolor/scalable/actions/`, registered via `Gtk::IconTheme#add_search_path` — a correspondence, not a gap, unchanged |
| Open component-level gaps | **0 confirmed missing widgets/CSS/signals/actions** |
| Driven-but-unverified branches carried from round 7 | **0 — all 5 closed this round, each re-verified below by reading what the new drive step actually asserts, not by trusting the commit message** |

`60ffe4d` is the only commit since round 7. `git show --stat 60ffe4d` touched
`lib/paper_clip/thumbnailer.rb` (9 lines), `test/drive_paper_clip.rb` (+248
lines) and three prose files. This round re-ran the drive harness and read
every new block the diff added, rather than re-deriving the whole inventory
from scratch — nothing else in `lib/` could have moved a component-parity
number, and nothing did.

## The five gaps round 7 carried forward, closed and re-verified this round

Round 7's `.reports/component-parity.md` named five undriven branches.
Re-read the actual new code in `test/drive_paper_clip.rb` (not the commit
message) for each:

| # | Gap, as round 7 left it | What the new drive step actually does | Verdict |
|---|---|---|---|
| 1 | `Thumbnailer::ExportError` never raised by any check | Points `create_cache_file` at a path whose parent directory does not exist, calls `thumbnailer.send(:export, ...)`, asserts `ExportError` is raised, is a `Thumbnailer::Error`, and its message names the file | **closed** — the error is genuinely forced and caught, not stubbed |
| 2 | `Thumbnailer::CacheError` never raised | Writes a plain file where `cache_directory` expects a directory, points `Dir.tmpdir` at it via `define_singleton_method`, asserts `CacheError` is raised and `Dir.tmpdir` is restored afterward | **closed** |
| 3 | `DocumentView`'s `@loading` guard never driven into firing | Forces `@loading = true` directly, edits a row to text the document does not have, asserts neither the document nor the dirty flag followed — then releases the guard and re-asserts the real write-back path still works | **closed** |
| 4 | `DateRow`'s `@syncing` guard never driven | Wraps the row's own `on_change` in a spy, assigns a date from outside (which itself fires `day-selected`), asserts the spy was **not** re-entered, then picks a day for real and asserts the spy fired exactly once with the real pick | **closed** |
| 5 | `Window#proceed_with_state`'s Discard and empty-selection-Save call sites unreached | Opens a fresh window via the `new-window` action for each case (so neither close risks the application's last window), edits it, blocks the close, answers Discard (or unticks the one row before Save), and asserts the window closes with the edit never written to disk | **closed** |

All five were re-run live this session as part of the 318/318 total, not
assumed from the diff alone.

## A bug the new coverage actually found, confirmed by reading the fix

Driving `ExportError` found that `write_to_png`'s real failure is
`Cairo::WriteError`, which is a Ruby `IOError`, not a `Cairo::Error` — so
`Thumbnailer#export`'s original `rescue Cairo::Error, SystemCallError`
let it through unrescued. `git show 60ffe4d -- lib/paper_clip/thumbnailer.rb`
confirms the fix is a one-line widening to `rescue Cairo::Error, IOError,
SystemCallError`, with a comment naming exactly why the narrower rescue was
wrong — not merely a broadened `rescue StandardError` that would have
silently swallowed the new failure mode along with everything else.

## Three-axis spot check on the units most recently touched

- **`thumbnailer.rb`**: read directly. The `rescue` clause is as the commit
  describes; `ExportError`/`CacheError` are both subclasses of
  `Thumbnailer::Error`, confirmed by `grep -n "class.*Error" lib/paper_clip/thumbnailer.rb`.
- **`document_view.rb`**'s `@loading` and **`date_row.rb`**'s `@syncing`:
  both guards already existed in the code (round 6's reading found them);
  what changed this round is only that a drive step now forces each one to
  matter. No `lib/` change was needed or made for either.
- **`window.rb`**'s `proceed_with_state`: unchanged source, now reached from
  all three call sites by name in the drive log (`grep -n
  "proceed_with_state\|Discard\|discard" test/drive_paper_clip.rb` shows the
  new Discard-path block).

## What is still outside the drive harness's reach, and why — unchanged from round 7

`drive-run.md`'s existing list (`g_application_open`'s inbound-only
marshalling, `AdwAlertDialog`'s missing `response()` binding,
`GtkFileDialog`'s async-only chooser) is unaffected by this round's commit —
none of those binding gaps were touched. Re-confirmed live: the 318-check
run still drives the open-path through a child process and still answers
alert dialogs by clicking the labeled button rather than emitting a signal.

## Rules applied

- Did not report parity from the drive harness total alone — read the
  actual new assertions for all five previously-open gaps rather than
  trusting "closed" in the commit message.
- Treated "a check exists for X" and "X is proven" as different claims,
  and verified each new block proves the specific behaviour named (the
  guard actually suppresses the loop, not merely that the method runs
  without raising).
- Re-ran the drive harness live in this session rather than citing a
  number from `PORTING.md` or `COMPONENT_PARITY.md`.
