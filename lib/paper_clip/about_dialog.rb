# frozen_string_literal: true

require 'adwaita'

require_relative 'poppler'
require_relative 'translations'
require_relative '../paper/clip/rb/version'

module PaperClip
  # AboutDialog is the about window, debug information included.
  #
  # Ported from on_about_action and generate_debug_info in upstream's
  # src/application.vala. The credits are upstream's — this is a port of their
  # application, so the people who wrote it are still the developers and the
  # artist — with the port itself named separately.
  #
  # `translator_credits` is set, from upstream's own msgid, so the eighteen
  # catalogues' credits lines reach the dialog (src/application.vala:191).
  #
  # The debug block lists every library a bug report needs. I did not keep
  # upstream's Poppler line, because this port links neither it nor Exempi: it
  # parses the PDF itself (see Document). That is a real difference in what a
  # bug report can say, and it is written down in FINDINGS.md as the cost of
  # the Poppler binding being unavailable rather than left implicit here.
  # GdkPixbuf is printed, because the port does link it. In Exempi's place,
  # since this port has no Exempi binding and edits the XMP packet as XML (see
  # XmpPacket) instead, the debug block names this gem's own version rather
  # than a library that never ran — a maintainer reading a bug report can then
  # tell which XMP code produced it.
  module AboutDialog
    include Translations

    APP_ID = 'io.github.diegoivan.pdf_metadata_editor'
    APP_NAME = 'Paper Clip'
    VERSION = '0.1.0'
    COPYRIGHT = '© 2023-2024 Diego Iván M.E'
    DEVELOPER_NAME = 'Diego Iván M.E'
    DEVELOPERS = ['Diego Iván M.E', 'The Ruby GTK Project'].freeze
    ARTISTS = ['Brage Fuglseth'].freeze
    WEBSITE = 'https://github.com/Diego-Ivan/Paper-Clip'
    ISSUE_URL = 'https://github.com/ruby-gtk-project/Paper-Clip-rb/issues'

    UNKNOWN_VERSION = 'unknown'

    def self.build
      Adwaita::AboutDialog.new.tap do |about|
        about.application_icon = APP_ID
        about.application_name = APP_NAME
        about.version = VERSION
        about.copyright = COPYRIGHT
        about.developer_name = DEVELOPER_NAME
        about.developers = DEVELOPERS
        about.artists = ARTISTS
        # TRANSLATORS: Write your name<email> here :D
        about.translator_credits = _('translator_credits')
        about.website = WEBSITE
        about.issue_url = ISSUE_URL
        about.license_type = Gtk::License::GPL_3_0
        about.debug_info = debug_info
      end
    end

    def self.debug_info
      <<~INFO
        Paper Clip #{VERSION} (Ruby port)
        Libraries:
        Gtk #{gtk_version} (Runtime)
        Libadwaita #{adwaita_version} (Runtime)
        GdkPixbuf #{pixbuf_version} (Runtime)
        Ruby #{RUBY_VERSION} #{RUBY_PLATFORM}
        Poppler #{poppler_version} (Runtime) — rendering only; metadata is parsed by this port
        XmpPacket #{Paper::Clip::Rb::Version::VERSION} (this gem) — no Exempi binding; XMP is read and rewritten as XML

        Running under Flatpak? #{flatpak?}
        OS Information? #{os_name}
      INFO
    end

    # Poppler is reached through its typelib rather than through a gem, so
    # there are no MAJOR/MINOR/MICRO constants to assemble: poppler_get_version
    # is the only version the library exposes, and it is a runtime one.
    def self.poppler_version
      Poppler.version
    rescue StandardError
      UNKNOWN_VERSION
    end

    def self.gtk_version = version_of(Gtk)
    def self.adwaita_version = version_of(Adwaita)
    def self.pixbuf_version = version_of(GdkPixbuf)

    # Which constants carry a library's version differs between the ruby-gnome
    # bindings, so the three spellings in circulation are all tried before
    # giving up — a missing version is not worth an exception in an about box.
    def self.version_of(namespace)
      [namespace::MAJOR_VERSION, namespace::MINOR_VERSION, namespace::MICRO_VERSION].join('.')
    rescue NameError
      version_from_module(namespace)
    end

    # `Version` is a module, not a value: `Gtk::Version.to_s` is the string
    # "Gtk::Version", which is what the About dialog used to print for Gtk and
    # GdkPixbuf. The version is in that module's STRING constant.
    def self.version_from_module(namespace)
      namespace::Version::STRING
    rescue NameError
      UNKNOWN_VERSION
    end

    def self.flatpak? = ::File.exist?('/.flatpak-info')

    # Upstream asks GLib for OsInfoKey.PRETTY_NAME; the same value is the
    # PRETTY_NAME line of /etc/os-release.
    def self.os_name
      ::File.read('/etc/os-release')[/^PRETTY_NAME="?([^"\n]*)"?/, 1].to_s
    rescue SystemCallError
      UNKNOWN_VERSION
    end
  end
end
