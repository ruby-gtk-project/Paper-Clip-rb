# Translation parity — Paper Clip (round 8 audit)

| | |
|---|---|
| Upstream | `origin/main` @ `c4db98e0bc2b8921d78c9e3fbf3d85ad2a124bd0` |
| Port | `ruby` @ `60ffe4d` |
| Upstream `.pot` msgids (`po/pdf-metadata-editor.pot`) | **87** (incl. the empty header) |
| Port's committed `.pot`, same filename | **87**, byte-identical to upstream's, re-diffed this round |
| `.po` files, both sides | **18**, same filenames |
| `.po` files with any byte difference from upstream's | **0** — re-diffed all 18 this round, none differ |
| Catalogue installed by `gem install paper-clip-rb` | translated in all 18 languages, unchanged since round 7's from-scratch gem rebuild — no `Rakefile`/gemspec change since |

`60ffe4d` is the only commit since round 7's audit and it touched
`lib/paper_clip/thumbnailer.rb`, `test/drive_paper_clip.rb` and three prose
files — nothing under `po/`, `locale/`, `Rakefile`'s gettext tasks, or the
gemspec's `files` list. So this round's expectation was that nothing here
had moved, and the re-run below confirms that rather than assuming it.

## Byte parity, re-diffed fresh this round

```sh
$ diff <(git show origin/main:po/pdf-metadata-editor.pot) po/pdf-metadata-editor.pot
# (no output — byte-identical)
$ diff <(git show origin/main:po/LINGUAS) po/LINGUAS
# (no output — byte-identical)
$ for f in po/*.po; do
    diff -q <(git show "origin/main:po/$(basename "$f")") "$f" || echo "DIFF: $f"
  done
# (no output — all 18 byte-identical)
```

All three checks were re-run live this round rather than carried from
round 7's text.

## The port's own extraction self-check — a different number, not a conflict

`rake gettext:pot` regenerates `po/pdf-metadata-editor.port.pot`, a
gitignored build artifact used only to prove the port's own source still
contains every string, independent of whether `po/pdf-metadata-editor.pot`
itself (the catalogue translators actually work against, carried over
byte-identical above) has ever been regenerated against the newest
upstream source.

```sh
$ nix develop --command rake gettext:pot
$ grep -c '^msgid "' po/pdf-metadata-editor.port.pot
97
$ diff <(git show origin/main:po/pdf-metadata-editor.pot | grep '^msgid "' | sort) \
       <(grep '^msgid "' po/pdf-metadata-editor.port.pot | sort)
11a12,13
> msgid "Contains Attachments"
> msgid "Contains JavaScript"
... (10 extra lines total, all '>' — none missing)
```

**Checked explicitly, because a number this different from the committed
documents' "96" needed reconciling rather than quoting past each other:**
`COMPONENT_PARITY.md` and `TRANSLATION_PARITY.md` both state "96" for this
same extraction (97 minus the empty header), which matches exactly. The
87-vs-96 split is **two different questions, not a contradiction**: 87 is
what the shipped `.pot` catalogue carries (byte-identical to upstream's own
shipped `.pot`, so a translator working from either file sees the same
87); 96 is everything `xgettext`/`rxgettext` can find marked for
translation across `lib/`, `exe/` **and** the four `data/` files
(`POTFILES`), which is a superset upstream's own `.pot` has never been
regenerated to include either — the diff above is one-directional (10
extra lines, 0 missing), meaning the port's source is not missing anything
upstream's shipped catalogue has; it is finding more than that catalogue
currently lists. This is not a port gap: it is upstream's own `.pot` being
stale relative to upstream's own source, which this port's extraction
check surfaces and the port's shipped catalogue does not inherit (the
shipped file stays byte-identical to upstream's, not to the port's own
extraction).

## Runtime check, re-confirmed

`spec/paper_clip/translations_spec.rb` was included in this round's fresh
134-example run (`0 failures`), and it asserts real catalogue lookups
(`LANGUAGE=de` → `"Ein Dokument öffnen"`, `LANGUAGE=fr` → `"Ouvrir un
document"`, and the `("shortcut window", "Close window")` context pair) —
not merely that the `.mo` files exist on disk.

## Rules applied

- Re-diffed all 18 `.po` files and the `.pot`/`LINGUAS` pair fresh this
  round rather than citing round 7's "0 byte differences" without
  re-running it.
- Did not let the 87-vs-96 figures sit unreconciled across documents —
  traced the difference to its actual cause (two different extraction
  scopes) rather than picking the number that happened to read as more
  impressive, and recorded which one is itself the gap (upstream's own
  `.pot` is behind upstream's own source, not something the port
  introduced or can fix by overwriting the catalogue translators use).
- Did not re-run the full from-scratch gem rebuild this round, since
  `60ffe4d` touched nothing that could have regressed it (confirmed by
  `git show --stat 60ffe4d`); said so explicitly rather than silently
  reusing round 7's number as if freshly checked.
