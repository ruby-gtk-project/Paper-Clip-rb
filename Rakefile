# frozen_string_literal: true

# kettle-jem:freeze
# To retain chunks of comments & code during kettle-jem templating:
# Wrap custom sections with freeze markers (e.g., as above and below this comment chunk).
# kettle-jem will then preserve content between those markers across template runs.
# kettle-jem:unfreeze

# paper-clip-rb Rakefile v7.1.28 - 2026-10-11
# Ruby 2.3 (Safe Navigation) or higher required
#
# See LICENSE.md for license information.
#
# Copyright (c) 2026 ruby-gtk-project (github.com)
#
# Expected to work in any project that uses Bundler.
#
# Sets up tasks for appraisal2, floss_funding, kettle-jem, kettle-dev, rspec, minitest, rubocop_gradual, reek, yard, and stone_checksums.
#
# rake appraisal:install                      # Install Appraisal gemfiles (initial setup...
# rake appraisal:reset                        # Delete Appraisal lockfiles (gemfiles/*.gemfile.lock)
# rake appraisal:generate                     # Generate Appraisal gemfiles without resolving...
# rake appraisal:update                       # Generate and update Appraisal gemfiles
# rake bench                                  # Run all benchmarks (alias for bench:run)
# rake bench:list                             # List available benchmark scripts
# rake bench:run                              # Run all benchmark scripts (skips on CI)
# rake build:generate_checksums               # Generate both SHA256 & SHA512 checksums i...
# rake bundle:audit:check                     # Checks the Gemfile.lock for insecure depe...
# rake bundle:audit:update                    # Updates the bundler-audit vulnerability d...
# rake ci:act[opt]                            # Run 'act' with a selected workflow
# rake coverage                               # Run specs w/ coverage and open results in...
# rake default                                # Default tasks aggregator
# rake install                                # Build and install paper-clip-rb-1.0.0.gem in...
# rake install:local                          # Build and install paper-clip-rb-1.0.0.gem in...
# rake kettle:jem:install                     # Internal target used by `kettle-jem install`
# rake kettle:jem:selftest                    # Self-test: template paper-clip-rb against itse...
# rake kettle:jem:template                    # Internal target used by scoped `kettle-jem template --only`
# rake reek                                   # Check for code smells
# rake reek:update                            # Run reek and store the output into the RE...
# rake release[remote]                        # Create tag v1.0.0 and build and push kett...
# rake rubocop_gradual                        # Run RuboCop Gradual
# rake rubocop_gradual:autocorrect            # Run RuboCop Gradual with autocorrect (onl...
# rake rubocop_gradual:autocorrect_all        # Run RuboCop Gradual with autocorrect (saf...
# rake rubocop_gradual:check                  # Run RuboCop Gradual to check the lock file
# rake rubocop_gradual:force_update           # Run RuboCop Gradual to force update the l...
# rake rubocop_gradual_debug                  # Run RuboCop Gradual
# rake rubocop_gradual_debug:autocorrect      # Run RuboCop Gradual with autocorrect (onl...
# rake rubocop_gradual_debug:autocorrect_all  # Run RuboCop Gradual with autocorrect (saf...
# rake rubocop_gradual_debug:check            # Run RuboCop Gradual to check the lock file
# rake rubocop_gradual_debug:force_update     # Run RuboCop Gradual to force update the l...
# rake spec                                   # Run RSpec code examples
# rake test                                   # Run tests
# rake yard                                   # Generate YARD Documentation
# rake yard:lint                              # Lint YARD Documentation
#

# simplecov:disable
require "bundler/gem_tasks" if !Dir[File.join(__dir__, "*.gemspec")].empty?
# simplecov:enable

# Define a base default task early so other files can enhance it.
desc "Default tasks aggregator"
task :default do
  puts "Default task complete."
end

# Without this, a generated docs/ directory makes Rake resolve the bare
# name `docs` as an up-to-date file task, so `rake docs` exits 0 having
# regenerated nothing.
desc "Generate YARD documentation"
task docs: "yard"

# simplecov:disable
### MONOREPO FAMILY TASKS
if Dir.exist?(File.join(__dir__, "gems"))
  def family_gem_dirs
    Dir.glob(File.join(__dir__, "gems", "*", "*.gemspec"))
      .map { |path| File.dirname(path) }
      .uniq
      .sort_by { |path| File.basename(path) }
  end

  def run_kettle_family(*args)
    sh("bundle", "exec", "kettle-family", *args)
  end

  namespace :family do
    desc "List released Ruby subgems"
    task :list do
      family_gem_dirs.each { |path| puts File.basename(path) }
    end

    desc "Run release readiness checks for the Ruby gem family"
    task :readiness do
      run_kettle_family("check")
    end

    desc "Run tests for the Ruby gem family"
    task :test do
      run_kettle_family("test", "--execute")
    end

    desc "Run lint for the Ruby gem family"
    task :lint do
      run_kettle_family("lint", "--execute")
    end

    desc "Generate YARD docs for the Ruby gem family"
    task :docs do
      run_kettle_family("docs", "--execute")
    end

    desc "Report release state for the Ruby gem family"
    task :release_state do
      run_kettle_family("release-state")
    end

    desc "Run the Ruby gem family release planner"
    task :release do
      run_kettle_family("release")
    end

    desc "Execute the Ruby gem family release"
    task :release_execute do
      run_kettle_family("release", "--execute")
    end
  end
end
# simplecov:enable

# External gems that define tasks - add here!
begin
  require "kettle/dev"
  Kettle::Dev.install_tasks unless Kettle::Dev::RUNNING_AS == "rake"
rescue LoadError
  warn("NOTE: kettle-dev isn't installed, or is disabled for #{RUBY_VERSION} in the current environment")
end

### TEMPLATING TASKS
# These tasks are installed for the `kettle-jem` executable. Run full templating
# through `kettle-jem install`; use `kettle-jem template --only PATH` only for
# scoped file updates. The executable prepares the environment and then
# delegates here when rake orchestration is needed.
kettle_jem_selftest_unavailable_note = nil
begin
  require "kettle/jem"
  if Kettle::Jem.respond_to?(:install_tasks)
    Kettle::Jem.install_tasks
  else
    kettle_jem_selftest_unavailable_note = "NOTE: kettle-jem #{Kettle::Jem::Version::VERSION} does not provide rake tasks in this environment"
  end
rescue LoadError
  kettle_jem_selftest_unavailable_note = "NOTE: kettle-jem isn't installed, or is disabled for #{RUBY_VERSION} in the current environment"
end

if kettle_jem_selftest_unavailable_note
  desc("(stub) kettle:jem:selftest is unavailable")
  task("kettle:jem:selftest") do
    warn(kettle_jem_selftest_unavailable_note)
  end
end

### RELEASE TASKS
# Setup stone_checksums
begin
  require "stone_checksums"
rescue LoadError
  desc("(stub) build:generate_checksums is unavailable")
  task("build:generate_checksums") do
    warn("NOTE: stone_checksums isn't installed, or is disabled for #{RUBY_VERSION} in the current environment")
  end
end

### TRANSLATION TASKS
# po/ is upstream's donated catalogue, carried across unchanged and in
# upstream's flat `po/<lang>.po` layout. GetText::Tools::Task is not used:
# it assumes `po/<lang>/<domain>.po` and litters po/ with timestamp
# directories for a layout this project does not have. The two tools are
# driven directly instead.
#
# locales come from po/LINGUAS rather than Dir["po/*.po"] so a language that
# loses its file loses it loudly.
begin
  require "gettext/tools/msgfmt"
  require "gettext/tools/xgettext"

  GETTEXT_DOMAIN = "pdf-metadata-editor"

  def gettext_locales
    File.read("po/LINGUAS").split
  end

  # po/POTFILES is upstream's own manifest of files that carry translatable
  # strings. Driving the source list off it, instead of a glob, is what
  # keeps the declared list and the extracted one from drifting apart: a
  # glob over lib/**/*.rb + exe/* silently drops the four data files
  # POTFILES still lists (the desktop entry, the gschema, the metainfo and
  # the Nautilus extension), which is how the port's .pot lost five of
  # upstream's 96 msgids. See TRANSLATION_PARITY.md.
  def gettext_potfiles
    File.readlines("po/POTFILES", chomp: true).reject(&:empty?)
  end

  def gettext_sources
    gettext_potfiles.select { |path| path.start_with?("lib/", "exe/") }
  end

  def gettext_data_files
    gettext_potfiles.select { |path| path.start_with?("data/") }
  end

  # Each non-Ruby format POTFILES lists needs its own xgettext front end:
  # rxgettext (the Ruby gem, used for gettext_sources above) only parses
  # Ruby. The .desktop entry and the Nautilus extension have built-in
  # xgettext languages; the metainfo XML and the gschema XML need an ITS
  # 2.0 rule file, because xgettext has no built-in notion of either
  # format's own translatable elements.
  def gettext_xgettext_args_for(path)
    case path
    when /\.desktop\.in\z/
      ["--language=Desktop"]
    when /\.metainfo\.xml\.in\z/
      ["--its=po/its/metainfo.its"]
    when /\.gschema\.xml\z/
      ["--its=po/its/gschema.its"]
    when /\.py\z/
      ["--language=Python"]
    else
      raise "gettext:pot has no extractor for #{path}; add one to " \
        "gettext_xgettext_args_for rather than silently skipping it"
    end
  end

  # Extracts one data file with the system xgettext (GNU gettext-tools),
  # since rxgettext cannot read any of these formats, and returns the
  # temporary .pot it wrote.
  def gettext_extract_data_file(path, tmp_dir)
    out = File.join(tmp_dir, "#{path.tr("/", "_")}.pot")
    sh(
      "xgettext",
      "--from-code=UTF-8",
      "--force-po",
      "--package-name=#{GETTEXT_DOMAIN}",
      *gettext_xgettext_args_for(path),
      "-o",
      out,
      path,
    )
    out
  end

  namespace :gettext do
    namespace :mo do
      desc "Compile po/*.po into locale/<lang>/LC_MESSAGES/#{GETTEXT_DOMAIN}.mo"
      task :update do
        gettext_locales.each do |locale|
          target = File.join(
            "locale",
            locale,
            "LC_MESSAGES",
            "#{GETTEXT_DOMAIN}.mo",
          )
          mkdir_p(File.dirname(target))
          GetText::Tools::MsgFmt.run("po/#{locale}.po", "-o", target)
        end
      end
    end

    desc "Extract the port's own messages into po/#{GETTEXT_DOMAIN}.port.pot"
    task :pot do
      # Written beside upstream's .pot rather than over it: upstream's is the
      # record of what translators were given, and this one is the check that
      # every key the port shows still reaches a catalogue. Two extractors
      # feed it — rxgettext for the Ruby sources, the system xgettext (once
      # per format) for the four data files POTFILES also lists — and
      # msgcat merges their output into one catalogue the way upstream's own
      # po/meson.build merges per-file .pot fragments.
      require "tmpdir"
      Dir.mktmpdir("paper-clip-pot") do |tmp_dir|
        ruby_pot = File.join(tmp_dir, "ruby.pot")
        GetText::Tools::XGetText.run(
          *gettext_sources,
          "-o",
          ruby_pot,
          "--package-name=#{GETTEXT_DOMAIN}",
          "--add-comments=TRANSLATORS",
        )
        data_pots = gettext_data_files.map { |path| gettext_extract_data_file(path, tmp_dir) }
        sh(
          "msgcat",
          "--use-first",
          "--sort-by-file",
          ruby_pot,
          *data_pots,
          "-o",
          "po/#{GETTEXT_DOMAIN}.port.pot",
        )
      end
    end
  end

  desc "Compile every message catalogue"
  task gettext: "gettext:mo:update"
rescue LoadError
  desc("(stub) gettext:mo:update is unavailable")
  task("gettext:mo:update") do
    warn("NOTE: the gettext gem isn't installed in the current environment")
  end
end

### DATA VALIDATION TASKS
# Ports upstream's three declared `meson test` targets (data/meson.build),
# which the flake builds and installs but never checks:
#
#   test('Validate desktop file',  desktop-file-validate)
#   test('Validate appstream file', appstreamcli validate --no-net --explain)
#   test('Validate schema file',    glib-compile-schemas --strict --dry-run)
#
# Each is gated on the tool being on PATH, exactly as upstream gates them on
# `find_program(..., required: false)` — a missing validator skips its check
# with a note rather than failing the task, but a validator that IS present
# and rejects the file does fail it. See TEST_PARITY.md.
namespace :test do
  desc "Validate data/ against upstream's three meson.build tests"
  task :data do
    require "tmpdir"
    Dir.mktmpdir("paper-clip-data-check") do |tmp_dir|
      desktop_in = "data/io.github.diegoivan.pdf_metadata_editor.desktop.in"
      metainfo_in = "data/io.github.diegoivan.pdf_metadata_editor.metainfo.xml.in"
      schema_dir = "data"

      if find_executable0("desktop-file-validate")
        merged_desktop = File.join(tmp_dir, "io.github.diegoivan.pdf_metadata_editor.desktop")
        sh("msgfmt", "--desktop", "--template", desktop_in, "-d", "po", "-o", merged_desktop)
        sh("desktop-file-validate", merged_desktop)
      else
        warn("NOTE: desktop-file-validate not found on PATH; skipping 'Validate desktop file'")
      end

      if find_executable0("appstreamcli")
        merged_metainfo = File.join(tmp_dir, "io.github.diegoivan.pdf_metadata_editor.metainfo.xml")
        sh("msgfmt", "--xml", "--template", metainfo_in, "-d", "po", "-o", merged_metainfo)
        sh("appstreamcli", "validate", "--no-net", "--explain", merged_metainfo)
      else
        warn("NOTE: appstreamcli not found on PATH; skipping 'Validate appstream file'")
      end

      if find_executable0("glib-compile-schemas")
        sh("glib-compile-schemas", "--strict", "--dry-run", schema_dir)
      else
        warn("NOTE: glib-compile-schemas not found on PATH; skipping 'Validate schema file'")
      end
    end
  end
end

# The same PATH lookup `which` performs, standing in for meson's
# `find_program(..., required: false).found()`.
def find_executable0(name)
  ENV["PATH"].to_s.split(File::PATH_SEPARATOR).any? do |dir|
    File.executable?(File.join(dir, name))
  end
end
