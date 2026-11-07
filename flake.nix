{
  description = "Paper-Clip — a Ruby GTK4 port";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    utils.url = "github:numtide/flake-utils";
  };

  outputs =
    { self, nixpkgs, utils }:
    utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};

        # Shared libraries every ruby-gnome extension links against.
        gtkStack = with pkgs; [
          glib
          gobject-introspection
          cairo
          pango
          gdk-pixbuf
          graphene
          atk
          gtk4
          libadwaita
          harfbuzz
          librsvg
        ]
        # The Ruby `pkg-config` gem resolves `Requires.private` transitively and
        # hard-fails if any .pc in the chain is missing, so gtk4's whole private
        # closure has to be on PKG_CONFIG_PATH, not just its public deps.
        ++ (with pkgs; [
          fontconfig
          freetype
          libepoxy
          libpng
          libxkbcommon
          pcre2
          util-linux
          wayland
          zlib
          fribidi
          libdatrie
          libthai
          libselinux
          libsepol
          expat
          brotli
          bzip2
          graphite2
          icu
          libffi
          libxml2
          lerc
          libdeflate
          xz
          zstd
        ])
        # Un-prefixed names: the `xorg.*` package set is deprecated.
        ++ (with pkgs; [
          libx11
          libxau
          libxcursor
          libxdmcp
          libxext
          libxfixes
          libxi
          libxinerama
          libxrandr
          libxrender
          libxcb
          xorgproto
        ]);

        # ruby-gnome gems build C extensions with extconf.rb + the pkg-config
        # gem; nixpkgs only ships gemConfig entries for the GTK3-era subset, so
        # the GTK4 gems get their build inputs declared here.
        rubyGnomeGem = _attrs: {
          nativeBuildInputs = [ pkgs.pkg-config ];
          buildInputs = gtkStack;
        };

        gemConfig = pkgs.defaultGemConfig // {
          gdk4 = rubyGnomeGem;
          gsk4 = rubyGnomeGem;
          gtk4 = rubyGnomeGem;
          graphene1 = rubyGnomeGem;
          adwaita = rubyGnomeGem;
          rsvg2 = rubyGnomeGem;
        };

        # Poppler renders page one of the open PDF for the editor's thumbnail.
        # nixpkgs builds poppler-glib without introspection by default, and the
        # typelib is the whole point of having it here: there is no Poppler gem
        # in the closure, so `Poppler-0.18.typelib` loaded through
        # GObjectIntrospection is how lib/paper_clip/poppler.rb reaches it.
        #
        # Kept out of `gtkStack` deliberately: that list is the gem C
        # extensions' build inputs, and adding to it would rebuild every
        # ruby-gnome extension for a library none of them links against.
        # nixpkgs' gobject-introspection writes absolute store paths into the
        # typelib's shared-library field, so GI_TYPELIB_PATH is the only thing
        # the loader needs — no LD_LIBRARY_PATH.
        poppler = pkgs.poppler.override { introspectionSupport = true; };

        # `makeSearchPath` would take each package's *first* output, and glib's
        # first output is `bin`, which carries no typelibs — hence the explicit
        # `.out`. at-spi2-core is here for the Atk typelib.
        typelibPath = pkgs.lib.makeSearchPath "lib/girepository-1.0"
          (map (drv: drv.out or drv) (gtkStack ++ [ pkgs.at-spi2-core poppler ]));

        # nix/ and not the repo root: the root Gemfile is kettle-jem's
        # development bundle — rubocop, rspec, yard, the kettle-dev stack — and
        # must not end up in a packaged app's runtime closure. nix/Gemfile holds
        # the gemspec's runtime dependencies only.
        gems = pkgs.bundlerEnv {
          name = "Paper-Clip-gems";
          ruby = pkgs.ruby_3_4;
          inherit gemConfig;
          gemdir = ./nix;
          groups = [ "default" ];
        };

        # The same gemdir with the `test` group included: rspec belongs in the
        # devShell and not in the packaged app's runtime closure, and
        # bundlerEnv's `groups` is the only thing that keeps those apart.
        devGems = pkgs.bundlerEnv {
          name = "Paper-Clip-dev-gems";
          ruby = pkgs.ruby_3_4;
          inherit gemConfig;
          gemdir = ./nix;
          groups = [ "default" "test" ];
        };

        # The launcher is whatever the gemspec installs into exe/. Reading the
        # directory keeps this flake generic: no name to keep in step by hand.
        launcher = builtins.head (builtins.attrNames (builtins.readDir ./exe));

        # Optional directories: a port that has not grown translations or data
        # assets yet simply has none.
        optionalDirs = builtins.filter (d: builtins.pathExists (./. + "/${d}")) [
          "data"
          "po"
        ];
      in
      {
        packages.default = pkgs.stdenv.mkDerivation {
          pname = "Paper-Clip";
          version = "0.1.0";
          src = ./.;

          # Deliberately no wrapGAppsHook4: glib's setup hook relocates
          # share/glib-2.0/schemas during fixup, after wrapGAppsHook4 has
          # computed its wrapper arguments, so a schema would end up somewhere
          # the wrapper never looks. The wrapper below is built by hand and
          # points at both the pre- and post-move paths.
          #
          # gettext is build-time only: `msgfmt -c --check-format` is the check
          # that a translator's %s typo cannot crash the app in one language,
          # and the gettext gem's own rmsgfmt does not implement it. The
          # compiled catalogues are the only thing that reaches the closure.
          nativeBuildInputs = [ pkgs.makeWrapper pkgs.gettext ];
          buildInputs = [ gems poppler ] ++ gtkStack;

          dontBuild = true;

          installPhase = ''
            runHook preInstall

            mkdir -p $out/share/Paper-Clip
            cp -r lib $out/share/Paper-Clip/
            for d in ${pkgs.lib.escapeShellArgs optionalDirs}; do
              cp -r "$d" $out/share/Paper-Clip/
            done
            # exe/ sits next to lib/ so the launcher's `require "Paper-Clip"`
            # resolves against the copied tree.
            install -Dm755 exe/${launcher} $out/share/Paper-Clip/exe/${launcher}

            # Compile po/ into locale/<lang>/LC_MESSAGES/<domain>.mo, which is
            # where Translations.LOCALE_DIR looks. LINGUAS and not po/*.po, so
            # a language that loses its file loses it loudly.
            if [ -f po/LINGUAS ]; then
              for lang in $(cat po/LINGUAS); do
                install -d "$out/share/Paper-Clip/locale/$lang/LC_MESSAGES"
                msgfmt -c --check-format \
                  -o "$out/share/Paper-Clip/locale/$lang/LC_MESSAGES/pdf-metadata-editor.mo" \
                  "po/$lang.po"
              done
            fi

            # The desktop entry, the AppStream metainfo and the GSettings
            # schema are translated by msgfmt and AppStream rather than by the
            # gettext gem, which is why they are merged here and not read from
            # locale/ at runtime.
            if [ -f data/io.github.diegoivan.pdf_metadata_editor.desktop.in ]; then
              install -d $out/share/applications
              msgfmt --desktop --template data/io.github.diegoivan.pdf_metadata_editor.desktop.in \
                -d po -o $out/share/applications/io.github.diegoivan.pdf_metadata_editor.desktop
            fi

            # The D-Bus activation file, with @bindir@ resolved to this
            # output's bin/. Upstream substitutes the same variable through
            # configure_file (data/meson.build:43-50); sed is that
            # substitution without a build system to hold it. Without this
            # file the desktop entry's DBusActivatable=true is a promise the
            # session bus cannot keep.
            if [ -f data/io.github.diegoivan.pdf_metadata_editor.service.in ]; then
              install -d $out/share/dbus-1/services
              sed "s|@bindir@|$out/bin|g" \
                data/io.github.diegoivan.pdf_metadata_editor.service.in \
                > $out/share/dbus-1/services/io.github.diegoivan.pdf_metadata_editor.service
            fi

            if [ -f data/io.github.diegoivan.pdf_metadata_editor.metainfo.xml.in ]; then
              install -d $out/share/metainfo
              msgfmt --xml --template data/io.github.diegoivan.pdf_metadata_editor.metainfo.xml.in \
                -d po -o $out/share/metainfo/io.github.diegoivan.pdf_metadata_editor.metainfo.xml
            fi

            # The hicolor tree upstream ships, so the welcome page and the
            # About dialog find the application icon and the five bundled
            # symbolic icons without an icon search path of their own.
            if [ -d data/icons/hicolor ]; then
              install -d $out/share/icons
              cp -r data/icons/hicolor $out/share/icons/
            fi

            # Compile the GSettings schema the port ships.
            for schema in data/*.gschema.xml data/schemas/*.gschema.xml; do
              [ -f "$schema" ] || continue
              mkdir -p $out/share/glib-2.0/schemas
              cp "$schema" $out/share/glib-2.0/schemas/
            done
            if [ -d $out/share/glib-2.0/schemas ]; then
              ${pkgs.glib.dev}/bin/glib-compile-schemas $out/share/glib-2.0/schemas
            fi

            # -rbundler/setup puts the bundled gems on the load path, and
            # GI_TYPELIB_PATH keeps GObject-Introspection from re-registering
            # types the cairo gem's C extension has already registered.
            #
            # BUNDLE_WITHOUT=test because `groups` above leaves rspec out of
            # this closure while nix/Gemfile.lock still declares it:
            # bundler/setup materialises every group in the lock and raised
            # GemNotFound for rspec, so the installed launcher exited before
            # it could require the app. The devShell is unaffected — it has
            # both groups.
            makeWrapper ${gems.wrappedRuby}/bin/ruby $out/bin/${launcher} \
              --add-flags "-rbundler/setup" \
              --add-flags "-I$out/share/Paper-Clip/lib" \
              --add-flags "$out/share/Paper-Clip/exe/${launcher}" \
              --set GI_TYPELIB_PATH "${typelibPath}" \
              --set BUNDLE_WITHOUT "test" \
              --prefix XDG_DATA_DIRS : "$out/share" \
              --prefix XDG_DATA_DIRS : "$out/share/gsettings-schemas/Paper-Clip-0.1.0" \
              --prefix XDG_DATA_DIRS : "${pkgs.gsettings-desktop-schemas}/share/gsettings-schemas/${pkgs.gsettings-desktop-schemas.name}" \
              --prefix XDG_DATA_DIRS : "${pkgs.gtk4}/share/gsettings-schemas/${pkgs.gtk4.name}" \
              --prefix XDG_DATA_DIRS : "${pkgs.adwaita-icon-theme}/share"

            runHook postInstall
          '';

          meta = {
            description = "A Ruby GTK4 / Libadwaita port of Paper-Clip";
            mainProgram = launcher;
            platforms = pkgs.lib.platforms.linux;
          };
        };

        apps.default = utils.lib.mkApp { drv = self.packages.${system}.default; };

        devShells.default = pkgs.mkShell {
          name = "Paper-Clip-devshell";

          packages = [
            devGems
            devGems.wrappedRuby
            pkgs.bundler
            pkgs.bundix
            pkgs.pkg-config
            pkgs.glib.dev
            pkgs.gettext
            # rxgettext, the extractor `rake pot` drives. GNU xgettext claims
            # to support Ruby but only shells out to this, so without it
            # `xgettext --language=Ruby` fails.
            pkgs.rubyPackages_3_4.gettext
            # The spec runner. The suite is plain RSpec, so this is enough.
            pkgs.rubyPackages_3_4.rspec
            # This machine may have no display server at all, so the shell
            # carries one it can start itself: `xvfb-run ruby exe/<app>` both
            # launches the app and is how test/drive_*.rb is run.
            pkgs.xvfb-run
            pkgs.gsettings-desktop-schemas
            pkgs.adwaita-icon-theme
            # Page-one rendering for the editor thumbnail, reached through its
            # introspection typelib.
            poppler
            # `rake test:data`'s first two checks (desktop-file-validate,
            # appstreamcli validate --no-net --explain) gate on
            # find_executable0, the way upstream's meson.build gates the same
            # two tools on find_program(..., required: false). Without these
            # on PATH the checks silently skip instead of actually running.
            pkgs.desktop-file-utils
            pkgs.appstream
          ] ++ gtkStack;

          # Icons, GSettings schemas and the GTK portal all resolve through
          # XDG_DATA_DIRS; without these the window opens with blank icons.
          shellHook = ''
            export XDG_DATA_DIRS="${pkgs.gsettings-desktop-schemas}/share/gsettings-schemas/${pkgs.gsettings-desktop-schemas.name}:${pkgs.gtk4}/share/gsettings-schemas/${pkgs.gtk4.name}:${pkgs.adwaita-icon-theme}/share:$XDG_DATA_DIRS"
            export GI_TYPELIB_PATH="${typelibPath}''${GI_TYPELIB_PATH:+:$GI_TYPELIB_PATH}"
            export RUBYLIB="$PWD/lib''${RUBYLIB:+:$RUBYLIB}"
            [ -d data/schemas ] && export GSETTINGS_SCHEMA_DIR="$PWD/data/schemas"
            unset BUNDLE_GEMFILE BUNDLE_FROZEN
            echo "Paper-Clip devshell — ruby $(ruby -e 'print RUBY_VERSION')"
            echo "run the app:   xvfb-run ruby exe/paper-clip"
            echo "drive the app: xvfb-run ruby test/drive_*.rb"
            echo "run the specs: ruby -e 'require \"rspec/core\"; exit RSpec::Core::Runner.run([\"--format\", \"progress\", \"--require\", \"spec_helper\", \"spec\"])'"
          '';
        };
      });
}
