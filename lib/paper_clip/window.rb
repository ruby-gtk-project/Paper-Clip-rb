# frozen_string_literal: true

require 'adwaita'

require_relative 'document'
require_relative 'document_manager'
require_relative 'document_view'
require_relative 'drop_overlay'
require_relative 'password_dialog'
require_relative 'primary_menu'
require_relative 'save_changes_dialog'
require_relative 'shortcuts_dialog'
require_relative 'translations'
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
  # * the one toast upstream shows, which is the one an incorrect password
  #   earns (src/window.vala:175). Every other failure goes to stderr, as
  #   upstream's `critical` calls do, rather than inventing a string no
  #   catalogue has.
  #
  # The state machine is upstream's and is the reason the window is not just a
  # pile of handlers: an unsaved document interrupts whatever was asked for.
  # Opening a file, or dropping one, or closing the window first raises the
  # save-changes dialog, and the state records what to resume afterwards.
  #
  # An encrypted document goes through PasswordDialog and is re-opened with
  # the password, which is what upstream's create_document does
  # (src/window.vala:183-199).
  class Window
    include Translations

    # Upstream marks the window title in window.ui; it is translated at use
    # rather than at definition so the locale is already set.
    TITLE = N_('Paper Clip')
    APP_ICON = 'io.github.diegoivan.pdf_metadata_editor'
    PDF_MIME = 'application/pdf'

    EMPTY_PAGE = 'empty'
    EDITOR_PAGE = 'editor'

    # The actions only a loaded document can service, which start disabled.
    DOCUMENT_ACTIONS = ['save', 'save-as', 'open-with'].freeze
    ACTIONS = (['open', 'main-menu'] + DOCUMENT_ACTIONS).freeze

    SHORTCUTS = {
      '<Control>o' => 'win.open',
      '<Control>w' => 'window.close',
      'F10'        => 'win.main-menu',
    }.freeze

    # Upstream's two animations are both 200 ms of EASE_IN_OUT_SINE
    # (src/window.vala:254 and :286).
    ANIMATION_DURATION = 200

    attr_reader :document_manager

    def initialize(app)
      @app = app
      @document_manager = DocumentManager.new
      @state = WindowState::NONE
      @dropped_file = nil
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
    #
    # The title is the application name only until a document is loaded;
    # DocumentView then tracks document.title onto it, which is upstream's
    # bind_property at src/DocumentView.vala:63.
    def window
      @window ||= Adwaita::ApplicationWindow.new(@app).tap do |win|
        win.title = _(TITLE)
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
        button.tooltip_text = _('Select a File')
        button.child = open_button_content
      end
    end

    def open_button_content
      @open_button_content ||= Adwaita::ButtonContent.new.tap do |content|
        content.icon_name = 'document-open-symbolic'
        content.label = _('Open')
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

    # accessible-role presentation, as window.ui:79 sets: the icon repeats
    # the heading below it, so a screen reader that announced it would read
    # the welcome page twice.
    def welcome_icon
      @welcome_icon ||= Gtk::Image.new(icon_name: APP_ICON).tap do |image|
        image.pixel_size = 128
        image.margin_bottom = 12
        image.accessible_role = :presentation
        image.add_css_class('icon-dropshadow')
      end
    end

    def welcome_title
      @welcome_title ||= Gtk::Label.new(_('Open a Document')).tap { |label| label.add_css_class('title-1') }
    end

    def welcome_subtitle = @welcome_subtitle ||= Gtk::Label.new(_('Drag and drop a PDF file here'))

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

      # Gtk::ShortcutTrigger.new and not .parse_string: these bindings expose
      # gtk_shortcut_trigger_parse_string as the class's only constructor, so
      # the string goes to `new` and the named method does not exist. It
      # raised NoMethodError the first time the page was built.
      def shortcut(accelerator, action)
        Gtk::Shortcut.new(
          Gtk::ShortcutTrigger.new(accelerator),
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
        rescue GLib::Error => e
          warn(e.message)
          @state = WindowState::NONE
        end
      end

      # No title: upstream sets none (src/window.vala:137), and a title here
      # would be a user-visible string in a place the original does not have
      # one.
      def file_dialog
        Gtk::FileDialog.new.tap { |dialog| dialog.filters = pdf_filters }
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
      # a text file onto the window is refused rather than failing later. The
      # refusal is a log line and no UI, as src/window.vala:92 is.
      def on_file_dropped(file)
        if pdf?(file)
          @dropped_file = file
          @state = WindowState::OPENING_DROPPED
          open_dropped_file
          true
        else
          warn('File is not a PDF')
          false
        end
      end

      def pdf?(file)
        file.query_info('standard::*', :nofollow_symlinks).content_type == PDF_MIME
      rescue GLib::Error => e
        warn(e.message)
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

      # `password` is nil on the first attempt, which is the one that finds
      # out whether the file needs one at all.
      def load_document(file, password = nil)
        @pending_file = file
        pulse_progress_bar
        Document.open(
          file,
          password: password,
          on_done:  ->(document) { document_loaded(document) },
          on_error: ->(error) { document_failed(error, password) },
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

      # Upstream's create_document asks for a password when Poppler reports
      # the file encrypted and it has none to try, and shows the toast when
      # the password it was given turns out to be wrong
      # (src/window.vala:174-199).
      def document_failed(error, password)
        hide_progress_bar
        if error.is_a?(Document::EncryptedError) && password.nil?
          ask_for_password
        else
          report_failure(error, password)
        end
      end

      def report_failure(error, password)
        warn(error.message)
        if error.is_a?(Document::EncryptedError)
          add_toast(_('Failed to open the document. The provided password is incorrect.'))
        end
        @state = WindowState::NONE
      end

      def ask_for_password
        PasswordDialog.new.tap do |dialog|
          @password_dialog = dialog
          dialog.build
          dialog.ask(
            @pending_file,
            window,
            on_password: ->(password) { load_document(@pending_file, password) },
            on_cancel:   -> { @state = WindowState::NONE },
          )
        end
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

      def save_failed(error)
        hide_progress_bar
        warn(error.message)
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

      # The managers the dialog returned, not this window's own: the dialog
      # answers with exactly what was ticked, and upstream saves exactly
      # those (src/application.vala:168-174). Unticking every row therefore
      # means "save nothing and carry on", which is what the checkbox looks
      # like it means.
      def save_selected(managers)
        if managers.empty?
          proceed_with_state
        else
          save_managers(managers)
        end
      end

      def save_managers(managers)
        file_save_animation
        @pending_saves = managers.length
        managers.each do |manager|
          manager.save(nil, on_done: method(:one_saved), on_error: method(:one_save_failed))
        end
      end

      def one_saved(*)
        @pending_saves -= 1
        if @pending_saves <= 0
          saved
        end
      end

      def one_save_failed(error)
        warn(error.message)
        one_saved
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

      # One pulse per load, as upstream's pulse_progress_bar is
      # (src/window.vala:283): the bar is an indeterminate hint that work
      # started, not a repeating animation.
      def pulse_progress_bar
        progress_bar.opacity = 1
        progress_bar.pulse
      end

      def hide_progress_bar
        animate(
          progress_bar,
          'opacity',
          1,
          0,
        ).play
      end

      # The save indicator: fraction 0 to 1 over the same 200 ms, and the
      # fade when it is done, which is what upstream's `animation.done`
      # connection does (src/window.vala:257).
      def file_save_animation
        progress_bar.fraction = 0
        progress_bar.opacity = 1
        animate(
          progress_bar,
          'fraction',
          0,
          1,
        ).tap do |animation|
          animation.signal_connect('done') { hide_progress_bar }
          animation.play
        end
      end

      def animate(widget, property, from, to)
        Adwaita::TimedAnimation.new(
          widget,
          from,
          to,
          ANIMATION_DURATION,
          Adwaita::PropertyAnimationTarget.new(widget, property),
        ).tap { |animation| animation.easing = Adwaita::Easing::EASE_IN_OUT_SINE }
      end
  end
end
