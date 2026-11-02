# Findings — Paper-Clip-rb

Questions this port had to answer, what answering them cost, and what is
still owed. Nothing in this file is a reason for a gap; every entry is either
an answer or a price tag.

| | |
|---|---|
| Upstream | `origin/main` @ `c4db98e0bc2b8921d78c9e3fbf3d85ad2a124bd0` |
| Port | `ruby` branch |
| Round | 3 |

## 1. Poppler through GObject-Introspection — **answered**

Upstream reads and writes the PDF through `Poppler.Document`
(`src/Document.vala:28-35`, `:463-466`) and renders page one through
`Poppler.Page` (`src/Services/Thumbnailer.vala`).

Round 2 reported the typelib as absent and the thumbnail as owed. The route
it named — add the typelib to the flake and load it with
`GObjectIntrospection::Loader` — is the one taken this round, and it worked.

**What was missing, and why it looked unavailable:** nixpkgs builds
`poppler-glib` with introspection off by default, so the package in the
closure genuinely carried no `lib/girepository-1.0`. The override is one
line:

```nix
poppler = pkgs.poppler.override { introspectionSupport = true; };
```

which yields `Poppler-0.18.typelib` with the absolute store path to
`libpoppler-glib.so.8` written into its shared-library field — so
`GI_TYPELIB_PATH` alone is enough and no `LD_LIBRARY_PATH` is involved. It is
added to `typelibPath`, to the devShell and to the package's `buildInputs`,
and deliberately *not* to `gtkStack`: that list is the gem C extensions'
build inputs, and widening it would rebuild every ruby-gnome extension for a
library none of them links against.

**Three things the loader did not do by itself**, each now in
`lib/paper_clip/poppler.rb`:

| Problem | Answer |
|---|---|
| `Poppler::Document` has seven constructors, and the loader folds them into one `initialize` that tries each until one accepts the arguments. `new_from_data` takes two strings, so it won the race for `(uri, password)` and reported every valid PDF as `Poppler::Error::Damaged` — it had read the URI as the file's bytes | `Poppler.open` allocates and calls the private `initialize_new_from_file` the loader also defines, which names the signature instead of guessing at it |
| `Poppler::Page#render` takes a `cairo_t`, and nothing converts a `Cairo::Context` into one unless the cairo gem is loaded first | `require 'cairo'` precedes the typelib load |
| The GVL is held across C calls by default, which would have made the "off-thread" render stall the main loop anyway | `Poppler::Loader#should_unlock_gvl?` names `render` and the two `render_for_printing` variants |

`Poppler::Error::Damaged` is also worth recording: the error domain's classes
descend from `GLib::ErrorInfo`, **not** from `GLib::Error`, so a
`rescue GLib::Error` lets them straight through. `Document#open_with_poppler`
rescues `Poppler::Error` beside it.

**What the user gets:** the page-one preview, in
`lib/paper_clip/document_thumbnail.rb` and `lib/paper_clip/thumbnailer.rb` —
white backing rectangle, `NEAREST`/`TRILINEAR` filter choice, `MAX_SIZE =
350`, the off-thread render and the downscaled PNG cache in
`$TMPDIR/thumbnails`. The `icon-dropshadow` class is on the image it belongs
on. `Document#get_page_for_index` is the model-layer accessor that was
missing with it.

**What Poppler is still not used for:** reading or writing metadata.
`lib/paper_clip/document.rb` continues to parse the file itself — objects,
object streams, trailers, the Info dictionary, the catalog, the viewer
preferences, the page tree — and to write an incremental update back, all of
it pinned by `spec/paper_clip/document_spec.rb`. Poppler is opened lazily,
for rendering only, and a file Poppler refuses but this parser accepts costs
the preview and nothing else. That is deliberate: making Poppler the reader
would narrow the set of files the editor opens at all.

## 2. libexempi for XMP — **answered without a binding**

Upstream mirrors the Info dictionary into the XMP packet through Exempi
(`src/Document.vala:227-270`), via `vapi/exempi-2.0.vapi`.

There is no Ruby binding to `libexempi`: no gem, no typelib (it is a plain C
library with no GObject introspection data at all), and `libexempi.so` is not
in this closure. An FFI binding would have been possible — `ffi` is in
nixpkgs — but it would have meant declaring `XmpFilePtr`, `XmpPtr`,
`xmp_files_open`, `xmp_files_get_new_xmp`, `xmp_set_property`,
`xmp_set_property_date`, `xmp_delete_property`, `xmp_files_can_put_xmp`,
`xmp_files_put_xmp` and `xmp_files_close`, plus a date struct, in order to
write seven simple properties.

**What was built instead:** `lib/paper_clip/xmp_packet.rb` edits the packet as
the XML it is. It handles both RDF carriers (child element and
`rdf:Description` attribute), writes `dc:title` as a language alternative
under `x-default`, deletes `CreateDate`/`ModifyDate` rather than blanking
them, stamps `MetadataDate` on every save, and leaves a schema it was not
asked about byte-identical. `spec/paper_clip/xmp_packet_spec.rb` pins all of
that, including the round trip through `Document#save`.

**What this costs:** the About dialog can no longer print an Exempi version,
because the port links none. That is stated in the comment on
`lib/paper_clip/about_dialog.rb` and recorded in `COMPONENT_PARITY.md`.

**Open question for a later round:** upstream's Exempi path writes through
`xmp_files_put_xmp`, which can relocate the packet and repad it. The port
appends a fresh revision of the `/Metadata` stream object instead. Both are
valid; a PDF/A validator should be run over the result before this is called
settled, and no PDF/A validator is in this closure.

## 3. The standard security handler — **built, because the dialog needed it**

Round 1 refused encrypted documents. Round 2 builds `PasswordDialog`, and a
dialog that collects a password and then still cannot open the file is worse
than no dialog, so `lib/paper_clip/pdf_crypt.rb` implements the handler
Poppler would have provided:

- `/R` 2 and 3 (RC4, 40- and 128-bit), 4 (RC4 or AES-128 through
  `/CF /StdCF /CFM`), 5 and 6 (AES-256);
- Algorithms 2, 5, 6 and 7 for the legacy key and both password checks;
- Algorithm 2.B for `/R` 6, including the hardening loop;
- Algorithm 1 for the per-object key, with the AESV2 salt.

RC4 is implemented in Ruby: `OpenSSL::Cipher.new("RC4")` raises on this
platform, and a 40-bit PDF from 2003 still has to open. The implementation is
checked against the RFC 6229 test vector, not only against itself.

`spec/paper_clip/pdf_crypt_spec.rb` opens one fixture per revision with the
user password, with the owner password, and with a wrong password, and
round-trips an edit back through a save. The fixtures were produced by `qpdf`
— see `spec/fixtures/README.md` — because a fixture produced by the code under
test proves nothing about it. The saved files were also read back by `qpdf`
independently, which is what established that the new `/Title` survives the
incremental update under all four revisions.

**Cost:** about 430 lines upstream does not have, and a dependency on
OpenSSL's AES, which is in the standard library.

## 4. The save-changes dialog's document title — **a proposal, not a change**

Round 1 made `DocumentRow` fall back to the filename when `/Title` is empty.
Upstream shows the empty title (`src/SaveChangesDialog.vala`). That was a
unilateral change to someone else's dialog at the one moment a user is
deciding whether to lose their edits, so round 2 reverted it:
`lib/paper_clip/document_row.rb` now shows `document.title` exactly as
upstream does.

**The proposal, for upstream:** a PDF with no `/Title` is common, and the row
then shows a blank title over its filename subtitle. Falling back to the
basename would make the row always say which document it is. This is worth an
issue against `Diego-Ivan/Paper-Clip`; until it is filed and answered, the
port matches upstream.

## 5. `po/POTFILES` is stale upstream — **report, do not copy the mistake**

`po/POTFILES` on `origin/main` lists
`data/io.github.diegoivan.pdf_metadata_editor.appdata.xml.in`, which no
longer exists (the file is `...metainfo.xml.in`), and omits seven live source
files: `src/DetailsList.vala`, `src/KeywordList.vala`, `src/KeywordRow.vala`,
`src/DateRow.vala`, `src/window.vala`, `src/StringArrayRow.vala` and
`src/SaveChangesDialog.vala`. Strings from several of those files do appear in
the `.po` catalogues, so the list has drifted since the last successful
extraction rather than those strings never having been offered.

**Worth reporting upstream.** The port carries all 96 keys regardless, and
`po/POTFILES` here lists the port's own files.

## 6. `Adw.ShortcutsSection` has no `max-height` — **a correspondence**

`src/gtk/shortcut-window.ui:8` sets `max-height="10"` on a
`GtkShortcutsSection`. That widget is deprecated in GTK 4.18, so the port uses
`Adw.ShortcutsDialog`, whose `ShortcutsSection` exposes `item-type`,
`n-items` and `title` and nothing else — the dialog sizes and paginates
itself. Verified by introspection against the installed `Adw` typelib, not
assumed. Recorded in `COMPONENT_PARITY.md` with the reason.

## 7. ruby-gettext does not resolve a text domain for an anonymous class

Found while writing `spec/paper_clip/translations_spec.rb`. `bindtextdomain`
registers the domain against the calling class, and a lookup resolves by
walking the caller's ancestors — but `Class.new { include Translations }` never
resolves, and returns the msgid instead. Every class in the port is named, so
this is not a constraint on the app; it is a trap that looks exactly like a
missing catalogue. The note lives in `spec/support/translated_host.rb`.

The same spec file records the second half: ruby-gettext resolves the locale
from the environment at the first lookup, and `set_locale` after that does not
move it. The German and French assertions therefore run in a child process
started with `LANGUAGE` set, which is also how a user gets a translation.

## 8. The app had never been started — **driven this round, and it was broken**

Rounds 1 and 2 recorded this as blocked on there being no display. The
devShell now carries `pkgs.xvfb-run`, so the block is gone, and the app was
driven for the first time:

```sh
nix develop --command xvfb-run -a ruby exe/paper-clip <file.pdf>
```

It did not start. Three separate binding-name mistakes stood between the
entry point and a window, each of which `ruby -c` and a successful `require`
pass straight over, and each of which a static reading of the source had
already called parity:

| Written | Exists | Where | Effect |
|---|---|---|---|
| `Gtk::IconTheme.for_display(display)` | `get_for_display` | `application.rb`, in `startup` | `NoMethodError` before any window was built — the app could not open at all |
| `file.query_exists?` | `query_exists` | `application.rb`, in `pdf?` | `NoMethodError` on every file the desktop or the command line handed it |
| `Gtk::ShortcutTrigger.parse_string(accel)` | `Gtk::ShortcutTrigger.new(accel)` | `window.rb`, `document_view.rb`, `password_dialog.rb`, `keyword_list.rb` | `NoMethodError` the first time each of those four pages was built — so every keyboard shortcut in the app, including the Ctrl+S the parity table listed as present |

The pattern behind all three: these bindings keep the C name. A static
`get_` prefix survives, a `gboolean` return does not become `?`, and a
constructor named `*_parse_string` is reachable only as `new`. Round 2's
`COMPONENT_PARITY.md` scored the shortcut controllers as parity on a reading
of the source; they had never once been constructed.

The installed launcher was broken too, for an unrelated reason:
`bundler/setup` materialises every group in `nix/Gemfile.lock`, including the
`test` group that `groups = [ "default" ]` deliberately leaves out of the
runtime closure, and raised `Bundler::GemNotFound` for rspec. The wrapper now
sets `BUNDLE_WITHOUT=test`. Before that fix the only way the app ran was from
the repository, where the devShell's `RUBYLIB` happened to cover for it.

**The lesson, stated plainly:** a widget verdict reached by reading source is
worth very little. Everything claimed for the thumbnail this round was
checked by running it — the editor page reaching `GtkRenderNodePaintable` at
350×525 for a portrait page, both the memory and the PNG-cache branches of
`Thumbnailer`, and both editor shortcuts resolving to `action(win.save)` and
`action(win.save-as)` and activating.

**Still owed:** screenshots, and a driver checked into the repository rather
than written per session. The scripts used this round were scratch files.

## 9. The spec harness is not the repo's own

`spec/spec_helper.rb` is a kettle-jem scaffold. It requires
`kettle/test/rspec`, and `kettle-test` is not in `nixpkgs`, so `rake spec`
cannot run in this environment. The `require` is now wrapped in the same
`rescue LoadError` the scaffold already uses for `kettle-soup-cover`, and
nothing in `spec/` depends on the harness helpers.

`spec/spec_helper.rb` requires `paper/clip/rb`, which did not exist and made
the harness unloadable. `lib/paper/clip/rb.rb` now exists and loads
`lib/paper_clip/models.rb`: the half of the port that touches no widget
toolkit. It deliberately does not load `lib/paper_clip.rb`, because that
requires `gtk4`, whose `require` calls `gtk_init` and raises on a machine with
no display — which is where a test suite runs. The GUI entry point is
`exe/paper-clip`, which requires `paper_clip`.

The suite runs with:

```sh
nix develop --command rspec --require ./spec/spec_helper.rb -Ilib -Ispec spec
```

`rake spec` will work wherever the kettle stack installs. That is a packaging
difference, and it is written down here rather than left for the next reader
to rediscover.

## 10. The flake's `src` is the git tree

Three data files were written, the package built, and `data/` was silently
absent from the output. `src = ./.` in a flake is the *flake source*, which
for a git repository is the tracked tree: an untracked file does not exist as
far as `builtins.pathExists` and the copy are concerned. Staging the files
fixed it. Worth knowing before the next round adds `data/` content and
believes the build.
