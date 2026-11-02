# frozen_string_literal: true

require 'adwaita'

module PaperClip
  # AboutDialog is the about window, debug information included.
  #
  # Ported from on_about_action and generate_debug_info in upstream's
  # src/application.vala. The credits are upstream's — this is a port of their
  # application, so the people who wrote it are still the developers and the
  # artist — with the port itself named separately.
  #
  # The debug block upstream prints lists the versions of every library it
  # links against. The ones this port does not use (Poppler and Exempi, whose
  # work the Document model does itself) are left out, and the Ruby and
  # ruby-gnome versions are added, because those are what a bug report against
  # this port needs.
  module AboutDialog
    APP_ID = 'io.github.diegoivan.pdf_metadata_editor'
    APP_NAME = 'Paper Clip'
    VERSION = '0.1.0'
    COPYRIGHT = '© 2023-2024 Diego Iván M.E'
    DEVELOPER_NAME = 'Diego Iván M.E'
    DEVELOPERS = ['Diego Iván M.E', 'The Ruby GTK Project'].freeze
    ARTISTS = ['Brage Fuglseth'].freeze
    WEBSITE = 'https://github.com/Diego-Ivan/Paper-Clip'
    ISSUE_URL = 'https://github.com/ruby-gtk-project/Paper-Clip-rb/issues'
    COMMENTS = 'A Ruby GTK4 and Libadwaita port of Paper Clip, the PDF metadata editor.'

    def self.build
      Adwaita::AboutDialog.new.tap do |about|
        about.application_icon = APP_ID
        about.application_name = APP_NAME
        about.version = VERSION
        about.copyright = COPYRIGHT
        about.developer_name = DEVELOPER_NAME
        about.developers = DEVELOPERS
        about.artists = ARTISTS
        about.comments = COMMENTS
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
        Ruby #{RUBY_VERSION} #{RUBY_PLATFORM}

        Running under Flatpak? #{flatpak?}
        OS Information? #{os_name}
      INFO
    end

    UNKNOWN_VERSION = 'unknown'

    def self.gtk_version = version_of(Gtk)
    def self.adwaita_version = version_of(Adwaita)

    # Which constants carry a library's version differs between the ruby-gnome
    # bindings, so the three spellings in circulation are all tried before
    # giving up — a missing version is not worth an exception in an about box.
    def self.version_of(namespace)
      [namespace::MAJOR_VERSION, namespace::MINOR_VERSION, namespace::MICRO_VERSION].join('.')
    rescue NameError
      version_from_module(namespace)
    end

    def self.version_from_module(namespace)
      namespace::Version.to_s
    rescue NameError
      UNKNOWN_VERSION
    end

    def self.flatpak? = ::File.exist?('/.flatpak-info')

    # Upstream asks GLib for OsInfoKey.PRETTY_NAME; the same value is the
    # PRETTY_NAME line of /etc/os-release.
    def self.os_name
      ::File.read('/etc/os-release')[/^PRETTY_NAME="?([^"\n]*)"?/, 1].to_s
    rescue SystemCallError
      'unknown'
    end
  end
end
