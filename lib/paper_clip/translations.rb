# frozen_string_literal: true

require 'gettext'

module PaperClip
  # Translations binds the port to upstream's message catalogue and hands out
  # the gettext markers every other file uses.
  #
  # Ported from the three Intl calls in upstream's src/application.vala:30-32.
  # Upstream passes Config.GETTEXT_PACKAGE, which is meson's project name,
  # `pdf-metadata-editor`; the domain *is* the `.mo` filename, so renaming it
  # to match this gem would orphan all eighteen of upstream's catalogues.
  #
  # `include GetText` binds a text domain to a class, not to the process, so
  # the pattern here is the one the ruby-gettext reference calls the small-port
  # shape: include and bind once, in a module every file requires, and let the
  # includers inherit the lookup through the ancestor chain. `included` also
  # extends the including class so a constant in a class body — which is where
  # most of this port's user-visible strings live — can call `_()` while the
  # class is still being defined.
  #
  # Three strings are marked here rather than at their use site because they
  # are table entries read back later: see N_ in pdf_strings.rb and main.rb.
  module Translations
    # Upstream's gettext package, from meson.project_name().
    TEXT_DOMAIN = 'pdf-metadata-editor'

    # `locale/<lang>/LC_MESSAGES/<domain>.mo`, built by `rake gettext:mo:update`
    # from po/. Omitting `path:` would make lookup depend on the working
    # directory and silently find nothing when the app is launched from a
    # desktop file.
    LOCALE_DIR = ::File.expand_path('../../locale', __dir__)

    include GetText

    bindtextdomain(TEXT_DOMAIN, path: LOCALE_DIR)

    # GLib and AppStream translate the gschema, the desktop entry and the
    # metainfo from the same catalogue, and they read it through libintl
    # rather than through the gem.
    def self.bind_glib_domain
      GLib::GetText.bindtextdomain(TEXT_DOMAIN, LOCALE_DIR)
    rescue NameError, NoMethodError
      nil
    end

    def self.included(base)
      base.extend(self)
      super
    end
  end
end
