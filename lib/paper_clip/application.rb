# frozen_string_literal: true

require 'gtk4'
require 'adwaita'

require_relative 'about_dialog'
require_relative 'style'
require_relative 'translations'
require_relative 'save_changes_dialog'
require_relative 'window'

module PaperClip
  # Application is the application object: the app-level actions, the windows
  # it opens, and the quit path that refuses to lose unsaved work.
  #
  # Ported from upstream's src/application.vala — its ActionEntry[] table and
  # the set_accels_for_action calls beside it, its activate and open
  # overrides, and its two-stage quit.
  #
  # Paper Clip is document-oriented: HANDLES_OPEN means the desktop can hand
  # it a PDF, and each file opens in a window of its own. A window can be
  # opened empty too, which is what Ctrl+N and the New Window menu item do.
  #
  # The quit is query-quit rather than quit because it has to ask first: it
  # gathers every window whose document has unsaved changes and puts them all
  # in one save-changes dialog, exactly as upstream does. Ctrl+Q is bound to
  # it, so the accelerator cannot discard work either.
  #
  # Adwaita::Application is still broken in these bindings, so the
  # application object is a Gtk::Application with Adwaita.init called before
  # any widget exists.
  #
  # Startup does the two things upstream's startup and constructor do besides
  # loading the stylesheet: it binds the GLib side of the text domain, which
  # is what translates the gschema, the desktop entry and the metainfo
  # (src/application.vala:29-30 — the Ruby side is bound in Translations), and
  # it puts the port's own icon directory on the GtkIconTheme search path,
  # which is the filesystem equivalent of upstream's gresource icon prefix in
  # src/pdf-metadata-editor.gresource.xml. Without it the five bundled
  # symbolic icons and the application icon are missing-image placeholders.
  #
  # Upstream also calls Xmp.init and Xmp.terminate here; this port has no
  # exempi binding and no global state to initialise, because XmpPacket is
  # pure Ruby.
  class Application
    include Translations

    APP_ID = 'io.github.diegoivan.pdf_metadata_editor'
    PDF_MIME = 'application/pdf'

    # Installed beside lib/, which is where the flake's installPhase copies
    # data/ to.
    ICON_DIRECTORY = ::File.expand_path('../../data/icons', __dir__)

    ACTIONS = {
      'about'      => [],
      'shortcuts'  => ['<Control>question'],
      'query-quit' => ['<Control>q'],
      'new-window' => ['<Control>n'],
    }.freeze

    def initialize(app_id: APP_ID, flags: :handles_open)
      @app_id = app_id
      @flags = flags
      @windows = []
    end

    def build
      app.tap do |a|
        a.signal_connect('startup') { on_startup }
        a.signal_connect('activate') { on_activate }
        a.signal_connect('open') { |_, files, _hint| on_open(files) }

        setup_actions
      end
    end

    def run(argv = []) = app.run(argv)

    def app = @app ||= build_app

    private

    # Adwaita.init runs before the application object exists, as the pilot
    # port does: an Adwaita widget built before init is styled wrongly.
      def build_app
        Adwaita.init
        Gtk::Application.new(@app_id, @flags)
      end

      def on_startup
        Translations.bind_glib_domain
        register_icons
        Style.apply
      end

      # add_search_path and not add_resource_path: the icons are installed as
      # files under data/icons, in the hicolor layout the icon-theme
      # specification describes.
      #
      # get_for_display and not for_display: the C name is
      # gtk_icon_theme_get_for_display, and these bindings keep the `get_`
      # prefix on a static method that takes an argument. The short name does
      # not exist, so startup raised NoMethodError and the app could not open
      # a window at all.
      def register_icons
        Gdk::Display.default.then do |display|
          if display
            Gtk::IconTheme.get_for_display(display).add_search_path(ICON_DIRECTORY)
          end
        end
      end

      def setup_actions
        ACTIONS.each { |name, accels| add_action(name, accels) }
      end

      def add_action(name, accels)
        Gio::SimpleAction.new(name, nil).tap do |action|
          action.signal_connect('activate') { send(:"action_#{name.tr('-', '_')}") }
          app.add_action(action)
          if accels.any?
            app.set_accels_for_action("app.#{name}", accels)
          end
        end
      end

      # --- Lifecycle --------------------------------------------------------

      def on_activate
        active_window.then do |window|
          if window
            window.present
          else
            new_window.present
          end
        end
      end

      # Upstream opens one window per file and skips anything that is not a
      # PDF rather than failing the whole invocation.
      def on_open(files)
        Array(files).each { |file| open_or_refuse(file) }
        on_activate
      end

      # Upstream logs the file it refused (src/application.vala:105), so a
      # user who double-clicks a .txt associated by accident gets a line they
      # can find rather than silence.
      def open_or_refuse(file)
        if pdf?(file)
          open_in_window(file)
        else
          warn("File #{file.path} is not a PDF")
        end
      end

      def open_in_window(file)
        new_window.tap do |window|
          window.open_command_line_file(file)
          window.present
        end
      end

      # query_exists and not query_exists?: the bindings keep the C name, and
      # the trailing question mark was a NoMethodError on every file the
      # desktop or the command line handed the application.
      def pdf?(file)
        file.query_exists && file.query_info('standard::*', :nofollow_symlinks).content_type == PDF_MIME
      rescue GLib::Error
        false
      end

      def new_window
        Window.new(app).tap do |window|
          @windows << window
          window.build
          window.window.signal_connect('destroy') { @windows.delete(window) }
        end
      end

      # The window the actions apply to. Adwaita windows are registered with
      # the application, so this is the application's own idea of which one
      # has focus rather than a list kept here.
      def active_window = app.active_window

      def window_for(toplevel)
        @windows.find { |window| window.window == toplevel }
      end

      # --- Actions ----------------------------------------------------------

      def action_about
        AboutDialog.build.present(active_window)
      end

      def action_shortcuts
        window_for(active_window)&.shortcuts
      end

      def action_new_window = new_window.present

      # Two stages: ask about the unsaved documents, then quit. With nothing
      # unsaved the dialog is skipped entirely.
      def action_query_quit
        unsaved_managers.then do |managers|
          if managers.empty?
            app.quit
          else
            ask_before_quitting(managers)
          end
        end
      end

      def unsaved_managers = @windows.map(&:document_manager).select(&:changed?)

      def ask_before_quitting(managers)
        SaveChangesDialog.new(managers, method(:on_quit_response)).tap do |dialog|
          @save_changes_dialog = dialog
          dialog.build
          dialog.present(active_window)
        end
      end

      def on_quit_response(response, managers)
        case response
        when SaveChangesDialog::SAVE then save_all(managers)
        when SaveChangesDialog::DISCARD then app.quit
        end
      end

      # Each save is asynchronous, so quitting waits until the last one has
      # reported back rather than racing the writes.
      def save_all(managers)
        @pending = managers.length
        if @pending.zero?
          app.quit
        else
          managers.each { |manager| manager.save(nil, on_done: method(:one_saved), on_error: method(:one_saved)) }
        end
      end

      def one_saved(*)
        @pending -= 1
        if @pending <= 0
          app.quit
        end
      end
  end
end
