# frozen_string_literal: true

require 'gtk4'
require 'adwaita'

require_relative 'about_dialog'
require_relative 'style'
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
  class Application
    APP_ID = 'io.github.diegoivan.pdf_metadata_editor'
    PDF_MIME = 'application/pdf'

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
        a.signal_connect('startup') { Style.apply }
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
        Array(files).select { |file| pdf?(file) }
                    .each { |file| open_in_window(file) }
        on_activate
      end

      def open_in_window(file)
        new_window.tap do |window|
          window.open_command_line_file(file)
          window.present
        end
      end

      def pdf?(file)
        file.query_exists? && file.query_info('standard::*', :nofollow_symlinks).content_type == PDF_MIME
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
