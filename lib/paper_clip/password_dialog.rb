# frozen_string_literal: true

require 'adwaita'

require_relative 'translations'

module PaperClip
  # PasswordDialog asks for the password of an encrypted document.
  #
  # Ported from upstream's src/PasswordDialog.vala and
  # src/gtk/password-dialog.ui: a compact status page over the filename, a
  # boxed-list password row, a pill Decrypt button, and Return and Escape
  # bound in the capture phase so they answer the dialog rather than the
  # entry.
  #
  # Upstream's `decrypt` is an async method that suspends on an AsyncTask and
  # resumes when the action group fires, then constructs the Document itself.
  # Ruby has no coroutine to suspend, so the two outcomes arrive as callbacks
  # — which is the same shape SaveChangesDialog uses, and the reason the
  # window keeps the dialog in an instance variable while it is on screen.
  #
  # The `closed` handler cancels, as upstream's on_closed does: a dialog
  # dismissed with the titlebar button must not leave the window waiting for
  # a password that is never coming.
  class PasswordDialog < Adwaita::Dialog
    include Translations

    TITLE = N_('Password Dialog')
    HEADING = N_('This Document Is Encrypted')
    PASSWORD_LABEL = N_('Password')
    DECRYPT_LABEL = N_('Decrypt')

    ICON = 'key-symbolic'

    ACTION_GROUP = 'dialog'
    SUCCESS_ACTION = 'success'
    CANCEL_ACTION = 'cancel'

    SHORTCUTS = {
      'Return' => "#{ACTION_GROUP}.#{SUCCESS_ACTION}",
      'Escape' => "#{ACTION_GROUP}.#{CANCEL_ACTION}",
    }.freeze

    WIDTH = 350
    HEIGHT = 320

    def initialize
      super()
      self.title = _(TITLE)
      self.width_request = WIDTH
      self.height_request = HEIGHT
      @on_password = nil
      @on_cancel = nil
      @answered = false
    end

    def build
      tap do |dialog|
        dialog.child = toolbar_view

        toolbar_view.tap do |view|
          view.add_top_bar(header_bar)
          view.content = status_page

          status_page.child = clamp

          clamp.child = content_box

          content_box.tap do |box|
            box.append(list_box)
            box.append(decrypt_button)

            list_box.append(password_row)
          end
        end

        dialog.insert_action_group(ACTION_GROUP, action_group)
        dialog.add_controller(shortcut_controller)
        dialog.signal_connect('closed') { cancel }
      end
    end

    # Upstream sets the status page's description to the basename of the file
    # it is asking about (src/PasswordDialog.vala:33), so the dialog says
    # which document wants a password when several windows are open.
    def ask(file, parent, on_password:, on_cancel:)
      @on_password = on_password
      @on_cancel = on_cancel
      @answered = false
      status_page.description = ::File.basename(file.path.to_s)
      present(parent)
    end

    def password = password_row.text

    # --- Widgets ------------------------------------------------------------

    def toolbar_view = @toolbar_view ||= Adwaita::ToolbarView.new

    # show-title false: the title is the window-manager name of the dialog,
    # and the status page already carries the heading a user reads.
    def header_bar
      @header_bar ||= Adwaita::HeaderBar.new.tap { |bar| bar.show_title = false }
    end

    def status_page
      @status_page ||= Adwaita::StatusPage.new.tap do |page|
        page.title = _(HEADING)
        page.icon_name = ICON
        page.add_css_class('compact')
      end
    end

    def clamp = @clamp ||= Adwaita::Clamp.new

    def content_box = @content_box ||= Gtk::Box.new(:vertical, 12)

    def list_box
      @list_box ||= Gtk::ListBox.new.tap do |box|
        box.selection_mode = :none
        box.add_css_class('boxed-list')
      end
    end

    def password_row
      @password_row ||= Adwaita::PasswordEntryRow.new.tap { |row| row.title = _(PASSWORD_LABEL) }
    end

    def decrypt_button
      @decrypt_button ||= Gtk::Button.new(label: _(DECRYPT_LABEL)).tap do |button|
        button.halign = :center
        button.action_name = "#{ACTION_GROUP}.#{SUCCESS_ACTION}"
        button.add_css_class('pill')
        button.add_css_class('suggested-action')
      end
    end

    def action_group
      @action_group ||= Gio::SimpleActionGroup.new.tap do |group|
        group.add_action(success_action)
        group.add_action(cancel_action)
      end
    end

    def success_action
      @success_action ||= Gio::SimpleAction.new(SUCCESS_ACTION, nil).tap do |action|
        action.signal_connect('activate') { succeed }
      end
    end

    def cancel_action
      @cancel_action ||= Gio::SimpleAction.new(CANCEL_ACTION, nil).tap do |action|
        action.signal_connect('activate') { cancel }
      end
    end

    # The capture phase is what upstream's propagation-phase property asks
    # for: without it Return is swallowed by the entry row and Escape by the
    # dialog's own default handling, so neither reaches the action.
    def shortcut_controller
      @shortcut_controller ||= Gtk::ShortcutController.new.tap do |controller|
        controller.propagation_phase = :capture
        SHORTCUTS.each { |accelerator, action| controller.add_shortcut(shortcut(accelerator, action)) }
      end
    end

    private

      def shortcut(accelerator, action)
        Gtk::Shortcut.new(
          Gtk::ShortcutTrigger.parse_string(accelerator),
          Gtk::NamedAction.new(action),
        )
      end

      # Upstream guards both handlers with `requires (task.status == RUNNING)`,
      # which is this flag: closing the dialog after a successful answer must
      # not then report a cancellation.
      def succeed
        answer { @on_password&.call(password) }
      end

      def cancel
        answer { @on_cancel&.call }
      end

      def answer
        unless @answered
          @answered = true
          close
          yield
        end
      end
  end
end
