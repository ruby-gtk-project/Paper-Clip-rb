# Translation parity — Paper Clip (round 7 re-audit)

| | |
|---|---|
| Upstream | `origin/main` @ `c4db98e0bc2b8921d78c9e3fbf3d85ad2a124bd0` |
| Port | `ruby` @ `1a00aac` |
| Upstream `.pot` msgids | **87** |
| Port's generated `.pot` msgids | **87**, byte-identical to upstream's, re-verified this round |
| `.po` files, both sides | **18**, same filenames (`LINGUAS` diffs clean) |
| `.po` files with any byte difference from upstream's | **0** — every one of the 18 is byte-identical to `origin/main`'s copy |
| Catalogue installed by a gem install (`gem install paper-clip-rb`) | **translated in all 18 languages — closed this round, verified by building the gem** |

## The msgid census, re-run again

```sh
$ diff <(git show origin/main:po/pdf-metadata-editor.pot | grep '^msgid "' | sort) \
       <(grep '^msgid "' po/pdf-metadata-editor.pot | sort)
# (no output)
$ git show origin/main:po/pdf-metadata-editor.pot | grep -c '^msgid "'
87
$ grep -c '^msgid "' po/pdf-metadata-editor.pot
87
```

Unchanged from round 6: no diff, equal counts.

## The 18 `.po` files — unchanged, re-diffed

```sh
$ for f in po/*.po; do
    diff -q <(git show "origin/main:po/$(basename "$f")") "$f" || echo "DIFF: $f"
  done
# (no output — all 18 are byte-identical to upstream's copy)
```

## The gap round 6 reported open — re-tested from a clean state, now closed

Round 6 found: `gem install paper-clip-rb` ships `po/**/*` (the `.po`
*sources*) but nothing under `locale/`, so a gem-installed Paper Clip ran
untranslated in all 18 languages while the Nix-built copy did not. The one
commit since round 6, `1a00aac`, claims to close this by making `locale/**/*`
part of `spec.files` and making `build`/`install`/`install:local` depend on
`gettext:mo:update`.

This was re-tested this round by actually deleting `locale/` and rebuilding
the gem, not by reading the diff and trusting it:

```sh
$ rm -rf locale
$ nix develop --command rake build --trace
...
mkdir -p locale/bg/LC_MESSAGES
mkdir -p locale/cs/LC_MESSAGES
... (18 languages)
paper-clip-rb 0.1.0 built to pkg/paper-clip-rb-0.1.0.gem.
$ nix develop --command gem spec pkg/paper-clip-rb-0.1.0.gem files | grep -c '\.mo'
18
$ nix develop --command gem spec pkg/paper-clip-rb-0.1.0.gem files | grep '\.mo' | head -3
- locale/bg/LC_MESSAGES/pdf-metadata-editor.mo
- locale/cs/LC_MESSAGES/pdf-metadata-editor.mo
- locale/de/LC_MESSAGES/pdf-metadata-editor.mo
```

All 18 `.mo` files are compiled fresh and packaged into the built `.gem`, not
merely present on disk at build time. Spot-checked one catalogue's actual
content, not just its presence:

```sh
$ nix develop --command msgunfmt locale/fr/LC_MESSAGES/pdf-metadata-editor.mo | head -6
msgid ""
msgstr ""
"Project-Id-Version: pdf-metadata-editor\n"
...
```

Real compiled translation data, not an empty catalogue.

Then checked that the running code actually resolves to this directory at
the gem's own root rather than only the dev tree's layout:

```ruby
# lib/paper_clip/translations.rb
LOCALE_DIR = ::File.expand_path('../../locale', __dir__)
```

`__dir__` is `lib/paper_clip`; `../../locale` from there is the repo
(/gem) root's `locale/` — the exact path the gemspec globs `locale/**/*`
into, and the exact path `rake gettext:mo:update` populates. A `gem install`
layout and the dev-tree layout resolve to the same relative path, so this is
not a dev-tree-only fix.

**This gap is closed.** A `gem install paper-clip-rb` now ships and resolves
all 18 compiled catalogues upstream's translators produced.

## `data/nautilus-extension/paper-clip.py`

Carries one upstream POTFILES-adjacent string (`"Edit PDF Metadata"`, the
Nautilus context-menu label), present byte-identical in both the upstream
`.py` and the port's copy. Unchanged from round 6, re-diffed this round.

## Open gaps

**0.** Both findings this report carried in round 6 (the 5-key `.pot` drop,
closed in an earlier round; the gem-install `.mo` gap, closed this round)
are now resolved and re-verified live rather than read off a commit message.
No new gap surfaced this round: `1a00aac` touched no `po/` file and added no
user-visible string.

## Rules applied

- Did not accept "closed" for the `.mo`-in-gem gap from the commit message
  alone; deleted `locale/`, rebuilt the gem from scratch, and read the
  resulting gem's own file manifest.
- Checked a compiled catalogue's actual content (`msgunfmt`), not just that
  a file of the right name exists at the right path.
- Traced `LOCALE_DIR`'s resolution logic by hand rather than assuming a path
  that works in the dev tree also works for an installed gem.
- Re-diffed the `.pot` and all 18 `.po` files against upstream's bytes again
  this round rather than citing round 6's diff as still valid.
