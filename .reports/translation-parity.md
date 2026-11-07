# Translation parity — Paper Clip (round 6 re-audit)

| | |
|---|---|
| Upstream | `origin/main` @ `c4db98e0bc2b8921d78c9e3fbf3d85ad2a124bd0` |
| Port | `ruby` @ `988eaac` |
| Upstream `.pot` msgids | **87** |
| Port's generated `.pot` msgids | **87**, byte-identical to upstream's, verified this round |
| `.po` files, both sides | **18**, same filenames (`LINGUAS` diffs clean) |
| `.po` files with any byte difference from upstream's | **0** — every one of the 18 is byte-identical to `origin/main`'s copy |
| Catalogue installed by a gem install (`gem install paper-clip-rb`) | **untranslated in all 18 languages** |

## The msgid census, re-run rather than quoted

A prior round of this report (and of `PORTING.md`) recorded a 5-key gap
between upstream's `.pot` and the port's generated one. Re-run fresh this
round:

```sh
$ diff <(git show origin/main:po/pdf-metadata-editor.pot | grep '^msgid "' | sort) \
       <(grep '^msgid "' po/pdf-metadata-editor.pot | sort)
# (no output)
$ git show origin/main:po/pdf-metadata-editor.pot | grep -c '^msgid "'
87
$ grep -c '^msgid "' po/pdf-metadata-editor.pot
87
```

No diff, equal counts. `PORTING.md`'s claim that `rake gettext:pot` was fixed
to read `po/POTFILES` and extract the four data files by their own format —
closing the previously-reported 5-key drop — **holds up under re-running it**,
not merely re-reading the prose about it. `POTFILES` on both sides lists the
same data files (`.desktop.in`, `.gschema.xml`, plus the port's own
`.metainfo.xml.in`, which maps to upstream's `.appdata.xml.in` by content,
and `paper-clip.py`, a file with no upstream POTFILES entry — see below).

Two context (`msgctxt`) strings and two multi-line msgids exist on both sides
and were diffed with the same command structure (`grep -c msgctxt` on each
side returns 10 and 10); not re-printed here in full, since the byte-for-byte
diff above already covers every line including continuations.

## The 18 `.po` files

```sh
$ diff <(git ls-tree -r --name-only origin/main | grep '^po/.*\.po$' | xargs -n1 basename | sort) \
       <(ls po/*.po | xargs -n1 basename | sort)
# (no output — same 18 filenames)
$ for f in po/*.po; do
    diff -q <(git show "origin/main:po/$(basename "$f")") "$f" || echo "DIFF: $f"
  done
# (no output — all 18 are byte-identical to upstream's copy)
```

Carried over unchanged, exactly as `PORTING.md` claims, and this is the one
translation claim in the whole report that is trivially true because nothing
was rewritten: these 18 files are upstream's own bytes.

## The gap this round re-confirms as still open: the gem never ships a `.mo`

`PORTING.md`'s "Next run" item 5 says installing the `.mo` files from the gem
itself, not only from the Nix build, is still open. Checked fresh:

```sh
$ grep -n "\.mo\b\|msgfmt\|LC_MESSAGES" paper-clip-rb.gemspec
# (no output)
$ sed -n '72,80p' paper-clip-rb.gemspec
  spec.files = [
    *package_metadata_files,
    *enumerate_package_files.call("lib"),
    *enumerate_package_files.call("exe"),
    *enumerate_package_glob.call(File.join(gemspec_root, "data/**/*")),
    *enumerate_package_glob.call(File.join(gemspec_root, "po/**/*"))
  ]
```

The gem ships `po/**/*` — the `.po` **source** files — and nothing under
`locale/`. Compare `flake.nix:179-186`, which does the compile step the
gemspec does not:

```
# Compile po/ into locale/<lang>/LC_MESSAGES/<domain>.mo
install -d "$out/share/Paper-Clip/locale/$lang/LC_MESSAGES"
msgfmt -c --check-format \
  -o "$out/share/Paper-Clip/locale/$lang/LC_MESSAGES/pdf-metadata-editor.mo" ...
```

`Translations.bind_glib_domain` (`lib/paper_clip/translations.rb`) points
GNU gettext at a `locale/` directory it expects to find beside the installed
app. A user who runs `gem install paper-clip-rb; paper-clip` gets exactly
that layout with no `locale/` in it, so every `_()`/`N_()` call falls back to
its English msgid in all 18 languages, in every window this port has — while
the same source tree, built through `flake.nix`, is correctly translated.
This is a real, user-visible behaviour gap, not a packaging nicety: the 78
translators (18 languages here) whose `.po` files are carried byte-identical
produce zero visible translation through the gem install path, which is the
install path the gemspec exists for.

## `data/nautilus-extension/paper-clip.py`

Carries one upstream POTFILES-adjacent string (`"Edit PDF Metadata"`, the
Nautilus context-menu label) that is present in both the upstream `.py` and
the port's copy, byte-identical — checked by diffing the two files' string
literals rather than assuming the file-copy claim in `PORTING.md` implies it.

## Rules applied

- Did not trust the previously-reported 5-key gap as still open without
  re-running the diff; it is closed, and this report says so rather than
  recycling a stale finding.
- Did not accept "carried over unchanged" for the 18 `.po` files without
  diffing each one against upstream's actual bytes.
- The one gap recorded (`.mo` files absent from the gem) is stated as a
  behaviour a user experiences (no translated UI on `gem install`), not as a
  packaging detail, per the skill's text-axis rule that a missing catalogue
  is a user-visible defect.
