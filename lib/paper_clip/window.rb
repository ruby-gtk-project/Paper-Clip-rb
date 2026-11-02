# frozen_string_literal: true

require 'adwaita'

require_relative 'document'
require_relative 'document_manager'
require_relative 'document_view'
require_relative 'drop_overlay'
require_relative 'primary_menu'
require_relative 'save_changes_dialog'
require_relative 'shortcuts_dialog'
require_relative 'window_state'

module PaperClip
  # Window is the application window: a header bar with an Open button and the
  # primary menu, a progress bar under it, and a stack that swaps between the
  # drag-and-drop welcome page and the editor.
  #
  # Ported from upstream's src/window.vala and src/window.ui, which between
  # them carry four things this one does too:
  #
  # * the welcome page — app icon, "Open a Document", "Drag and drop a PDF
  #   file here" — which is the stack's "empty" child;
  # * the win.open / win.open-with / win.save / win.save-as / win.main-menu
  #   actions, the last three disabled until a document is open, which is what
  #   makes them vanish from the primary menu;
  # * the Ctrl+O, Ctrl+W and F10 shortcuts from the window's
  #   GtkShortcutController;
  # * the toast shown when a document will not open.
  #
  # The state machine is upstream's and is the reason the window is not just a
  # pile of handlers: an unsaved document interrupts whatever was asked for.
  # Opening a file, or dropping one, or closing the window first raises the
  # save-changes dialog, and the state records what to resume afterwards.
  #
  # Upstream's progress bar is driven by Adw.TimedAnimation. This port drives
  # it from GLib::Timeout instead, which needs no animation target and makes
  # the pulse and the fade the same mechanism.
  class Window
    TITLE = 'Paper Clip'
    APP_ICON = 'io.github.diegoivan.pdf_metadata_editor'
    PDF_MIME = 'application/pdf'

    WELCOME_TITLE = 'Open a Document'
    WELCOME_SUBTITLE = 'Drag and drop a PDF file here'

    EMPTY_PAGE = 'empty'
    EDITOR_PAGE = 'editor'

    ENCRYPTED_TOAST = 'Failed to open the document. It is encrypted.'
    FAILED_TOAST = 'Failed to open the document.'
    NOT_PDF_TOAST = 'That file is not a PDF.'

    # The actions only a loaded document can service, which start disabled.
    DOCUMENT_ACTIONS = ['save', 'save-as', 'open-with'].freeze
    ACTIONS = (['open', 'main-menu'] + DOCUMENT_ACTIONS).freeze

    SHORTCUTS = {
      '<Control>o' => 'win.open',
      '<Control>w' => 'window.close',
      'F10'        => 'win.main-menu',
    }.freeze

    PULSE_INTERVAL = 100
    FADE_INTERVAL = 20
    FADE_STEPS = 10

    attr_reader :document_manager

    def initialize(app)
      @app = app
      @document_manager = DocumentManager.new
      @state = WindowState::NONE
      @dropped_file = nil
      @pulse = nil
    end

    def build
      window.tap do |win|
        win.content = toolbar_view

        toolbar_view.tap do |view|
          view.add_top_bar(top_box)
          view.content = toast_overlay

          top_box.tap do |box|
            box.append(header_bar)
            box.append(progress_bar)

            header_bar.tap do |bar|
              bar.pack_start(open_button)
              bar.pack_end(menu_button)
            end
          end

          toast_overlay.child = drop_overlay.build

          view_stack.tap do |stack|
            stack.add_named(welcome_clamp, EMPTY_PAGE)
            stack.add_named(document_view.build, EDITOR_PAGE)
            stack.add_controller(drop_target)

            welcome_clamp.child = welcome_box

            welcome_box.tap do |box|
              box.append(welcome_icon)
              box.append(welcome_title)
              box.append(welcome_subtitle)
            end
          end
        end

        drop_overlay.drop_target = drop_target
        drop_target.signal_connect('drop') { |_, value| on_file_dropped(value) }
        win.add_controller(shortcut_controller)
        win.signal_connect('close-request') { on_close_request }
        setup_actions
      end
    end

    def present = window.present

    # Called by the application when it is handed a file on the command line
    # or by the desktop. The file has already been checked to exist.
    def open_command_line_file(file)
      @state = WindowState::OPENING_FILE
      @dropped_file = file
      open_dropped_file
    end

    def shortcuts
      ShortcutsDialog.new.tap do |dialog|
        @shortcuts_dialog = dialog
        dialog.build
        dialog.present(window)
      end
    end

    # --- Widgets ------------------------------------------------------------

    # Adwaita::ApplicationWindow, not the Gtk one: the Gtk window draws a
    # default titlebar, which would sit above the Adwaita header bar and give
    # the window a second close button. It also keeps Adwaita dialogs inside
    # the window rather than spawning a second toplevel.
    def window
      @window ||= Adwaita::ApplicationWindow.new(@app).tap do |win|
        win.title = TITLE
        win.set_default_size(600, 500)
        win.set_size_request(350, 320)
      end
    end

    def toolbar_view = @toolbar_view ||= Adwaita::ToolbarView.new
    def header_bar = @header_bar ||= Adwaita::HeaderBar.new
    def top_box = @top_box ||= Gtk::Box.new(:vertical, 0)

    def open_button
      @open_button ||= Gtk::Button.new.tap do |button|
        button.action_name = 'win.open'
        button.tooltip_text = 'Select a File'
        button.child = open_button_content
      end
    end

    def open_button_content
      @open_button_content ||= Adwaita::ButtonContent.new.tap do |content|
        content.icon_name = 'document-open-symbolic'
        content.label = 'Open'
      end
    end

    def menu_button
      @menu_button ||= Gtk::MenuButton.new.tap do |button|
        button.icon_name = 'open-menu-symbolic'
        button.menu_model = PrimaryMenu.build
      end
    end

    # Opacity rather than visibility, as upstream does: a hidden progress bar
    # would change the height of the header area every time a file loads.
    def progress_bar
      @progress_bar ||= Gtk::ProgressBar.new.tap do |bar|
        bar.hexpand = true
        bar.opacity = 0.0
        bar.add_css_class('osd')
      end
    end

    def toast_overlay = @toast_overlay ||= Adwaita::ToastOverlay.new

    # The overlaid widget is an empty bin: the drag tint is a rectangle drawn
    # over the whole window, not a widget with contents of its own.
    def drop_overlay = @drop_overlay ||= DropOverlay.new(view_stack, overlay_bin)
    def overlay_bin = @overlay_bin ||= Adwaita::Bin.new

    def view_stack
      @view_stack ||= Gtk::Stack.new.tap { |stack| stack.transition_type = :crossfade }
    end

    def document_view = @document_view ||= DocumentView.new

    # --- The welcome page ---------------------------------------------------

    def welcome_clamp = @welcome_clamp ||= Adwaita::Clamp.new

    def welcome_box
      @welcome_box ||= Gtk::Box.new(:vertical, 15).tap { |box| box.valign = :center }
    end

    def welcome_icon
      @welcome_icon ||= Gtk::Image.new(icon_name: APP_ICON).tap do |image|
        image.pixel_size = 128
        image.margin_bottom = 12
        image.add_css_class('icon-dropshadow')
      end
    end

    def welcome_title
      @welcome_title ||= Gtk::Label.new(WELCOME_TITLE).tap { |label| label.add_css_class('title-1') }
    end

    def welcome_subtitle = @welcome_subtitle ||= Gtk::Label.new(WELCOME_SUBTITLE)

    # --- Controllers and actions --------------------------------------------

    def drop_target
      @drop_target ||= Gtk::DropTarget.new(Gio::File.gtype, :copy)
    end

    def shortcut_controller
      @shortcut_controller ||= Gtk::ShortcutController.new.tap do |controller|
        SHORTCUTS.each { |accelerator, action| controller.add_shortcut(shortcut(accelerator, action)) }
      end
    end

    def actions = @actions ||= {}

    private

      def shortcut(accelerator, action)
        Gtk::Shortcut.new(
          Gtk::ShortcutTrigger.parse_string(accelerator),
          Gtk::NamedAction.new(action),
        )
      end

      def setup_actions
        ACTIONS.each { |name| add_action(name) }
        DOCUMENT_ACTIONS.each { |name| actions[name].enabled = false }
      end

      def add_action(name)
        Gio::SimpleAction.new(name, nil).tap do |action|
          action.signal_connect('activate') { send(:"action_#{name.tr('-', '_')}") }
          window.add_action(action)
          actions[name] = action
        end
      end

      def enable_document_actions
        DOCUMENT_ACTIONS.each { |name| actions[name].enabled = true }
      end

      # --- Actions ----------------------------------------------------------

      def action_open
        @state = WindowState::OPENING_FILE
        if @document_manager.changed?
          show_unsaved_warning
        else
          open_file
        end
      end

      def action_open_with = document_view.open_on_app(window)
      def action_main_menu = menu_button.popup

      def action_save
        @document_manager.document.then do |document|
          if document && @document_manager.changed?
            save_to(document.path)
          end
        end
      end

      def action_save_as
        @document_manager.document.then do |document|
          if document
            @file_dialog = save_dialog(document)
            @file_dialog.save(window, nil) do |dialog, result|
              save_to(dialog.save_finish(result).path)
            rescue GLib::Error
              @state = WindowState::NONE
            end
          end
        end
      end

      # --- Opening ----------------------------------------------------------

      def open_file
        @file_dialog = file_dialog
        @file_dialog.open(window, nil) do |dialog, result|
          load_document(dialog.open_finish(result))
        rescue GLib::Error
          @state = WindowState::NONE
        end
      end

      def file_dialog
        Gtk::FileDialog.new.tap do |dialog|
          dialog.title = 'Open a Document'
          dialog.filters = pdf_filters
        end
      end

      def save_dialog(document)
        Gtk::FileDialog.new.tap do |dialog|
          dialog.initial_name = ::File.basename(document.path)
          dialog.filters = pdf_filters
        end
      end

      def pdf_filters
        Gio::ListStore.new(Gtk::FileFilter).tap do |filters|
          filters.append(
            Gtk::FileFilter.new.tap do |filter|
                    filter.name = 'PDF'
                    filter.add_mime_type(PDF_MIME)
                  end,
          )
        end
      end

      # Upstream checks the content type before accepting a drop, so dragging
      # a text file onto the window is refused rather than failing later.
      def on_file_dropped(file)
        if pdf?(file)
          @dropped_file = file
          @state = WindowState::OPENING_DROPPED
          open_dropped_file
          true
        else
          add_toast(NOT_PDF_TOAST)
          false
        end
      end

      def pdf?(file)
        file.query_info('standard::*', :nofollow_symlinks).content_type == PDF_MIME
      rescue GLib::Error
        false
      end

      def open_dropped_file
        if @document_manager.changed?
          show_unsaved_warning
        else
          load_dropped_file
        end
      end

      def load_dropped_file
        load_document(@dropped_file)
        @dropped_file = nil
      end

      def load_document(file)
        pulse_progress_bar
        Document.open(
          file,
          on_done:  ->(document) { document_loaded(document) },
          on_error: ->(error) { document_failed(error) },
        )
      end

      def document_loaded(document)
        @document_manager.document = document
        document_view.update(document)
        enable_document_actions
        view_stack.visible_child_name = EDITOR_PAGE
        hide_progress_bar
        @state = WindowState::NONE
      end

      # The error state: upstream's toast, shown when Poppler refuses the
      # file. The two cases it can refuse for are kept apart, because
      # "encrypted" is the one the user can do something about.
      def document_failed(error)
        if error.is_a?(Document::EncryptedError)
          add_toast(ENCRYPTED_TOAST)
        else
          add_toast(FAILED_TOAST)
        end
        hide_progress_bar
        @state = WindowState::NONE
      end

      def add_toast(message)
        toast_overlay.add_toast(Adwaita::Toast.new(message))
      end

      # --- Saving -----------------------------------------------------------

      def save_to(target_path)
        file_save_animation
        @document_manager.save(target_path, on_done: method(:saved), on_error: method(:save_failed))
      end

      def saved
        proceed_with_state
        @state = WindowState::NONE
      end

      def save_failed(_error)
        hide_progress_bar
        add_toast('Failed to save the document.')
        @state = WindowState::NONE
      end

      # --- The unsaved-changes interruption ---------------------------------

      def show_unsaved_warning
        SaveChangesDialog.new([@document_manager], method(:on_warning_response)).tap do |dialog|
          @save_changes_dialog = dialog
          dialog.build
          dialog.present(window)
        end
      end

      def on_warning_response(response, managers)
        case response
        when SaveChangesDialog::CANCEL then @state = WindowState::NONE
        when SaveChangesDialog::SAVE then save_selected(managers)
        else proceed_with_state
        end
      end

      def save_selected(managers)
        if managers.empty?
          proceed_with_state
        else
          save_to(@document_manager.document.path)
        end
      end

      def proceed_with_state
        case @state
        when WindowState::OPENING_FILE then open_file
        when WindowState::OPENING_DROPPED then load_dropped_file
        when WindowState::CLOSING then window.close
        end
      end

      # Returning true from close-request blocks the close, which is how the
      # dialog gets a chance to run; the state remembers that the window is
      # on its way out so the second attempt goes through.
      def on_close_request
        if !@document_manager.changed? || @state == WindowState::CLOSING
          @state = WindowState::NONE
          false
        else
          @state = WindowState::CLOSING
          show_unsaved_warning
          true
        end
      end

      # --- The progress bar -------------------------------------------------

      def pulse_progress_bar
        progress_bar.opacity = 1
        progress_bar.pulse
        @pulse ||= GLib::Timeout.add(PULSE_INTERVAL) do
          progress_bar.pulse
          true
        end
      end

      def stop_pulse
        if @pulse
          GLib::Source.remove(@pulse)
          @pulse = nil
        end
      end

      def hide_progress_bar
        stop_pulse
        progress_bar.opacity.then { |from| fade_out(from) }
      end

      def fade_out(from)
        step = 0
        GLib::Timeout.add(FADE_INTERVAL) do
          step += 1
          progress_bar.opacity = from * (1.0 - (step.to_f / FADE_STEPS))
          step < FADE_STEPS
        end
      end

      # The save indicator: a determinate sweep to full, then the same fade.
      def file_save_animation
        stop_pulse
        progress_bar.opacity = 1
        progress_bar.fraction = 0
        step = 0
        GLib::Timeout.add(FADE_INTERVAL) do
          step += 1
          progress_bar.fraction = step.to_f / FADE_STEPS
          sweep_step(step)
        end
      end

      def sweep_step(step)
        if step < FADE_STEPS
          true
        else
          hide_progress_bar
          false
        end
      end
  end
end
