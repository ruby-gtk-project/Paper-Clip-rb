# frozen_string_literal: true

require 'adwaita'

require_relative 'document_row'
require_relative 'translations'

module PaperClip
  # SaveChangesDialog asks what to do about documents with unsaved changes.
  #
  # Ported from upstream's src/SaveChangesDialog.vala and
  # src/gtk/save-changes-dialog.ui, including the SaveChangesResponse enum.
  # It lists every unsaved document with a checkbox, and answers Save,
  # Discard or Cancel.
  #
  # Upstream builds it on Adw.MessageDialog, which libadwaita deprecated in
  # 1.6; this is the same dialog on its replacement, Adw.AlertDialog, whose
  # responses and appearances work identically.
  #
  # Upstream's `ask` is an async function returning the response. Ruby has no
  # coroutines to suspend here, so the answer arrives through the on_response
  # callback — which is also why the window keeps the dialog in an instance
  # variable: nothing else would hold it while it is on screen.
  class SaveChangesDialog
    include Translations

    HEADING = N_('Save Changes?')
    # Adjacent literals, joined by the parser. rxgettext joins them too, so
    # upstream's longest msgid survives extraction — but a `+` or an
    # interpolation here would not, and the runtime lookup would go on looking
    # correct while the key never reached the catalogue.
    BODY = N_(
      'Open documents contain unsaved changes. Changes which are not saved will be ' \
      'permanently lost.',
    )

    CANCEL = :cancel
    DISCARD = :discard
    SAVE = :save

    # on_response is called with the response and the managers still ticked.
    def initialize(managers, on_response)
      @managers = Array(managers).select(&:changed?)
      @on_response = on_response
    end

    def build
      dialog.tap do |d|
        d.extra_child = scroller

        scroller.tap do |s|
          s.child = list_box

          list_box.tap { |box| rows.each { |row| box.append(row) } }
        end

        d.signal_connect('response') { |_, response| @on_response.call(response.to_sym, selected_managers) }
      end
    end

    def present(parent) = dialog.present(parent)

    def selected_managers = rows.select(&:selected?).map(&:manager)

    def dialog
      @dialog ||= Adwaita::AlertDialog.new(_(HEADING), _(BODY)).tap do |d|
        d.add_response(CANCEL.to_s, _('_Cancel'))
        d.add_response(DISCARD.to_s, _('_Discard'))
        d.add_response(SAVE.to_s, _('_Save'))
        d.set_response_appearance(DISCARD.to_s, Adwaita::ResponseAppearance::DESTRUCTIVE)
        d.set_response_appearance(SAVE.to_s, Adwaita::ResponseAppearance::SUGGESTED)
        d.default_response = SAVE.to_s
        d.close_response = CANCEL.to_s
      end
    end

    def scroller
      @scroller ||= Gtk::ScrolledWindow.new.tap do |s|
        s.propagate_natural_height = true
        s.propagate_natural_width = true
      end
    end

    def list_box
      @list_box ||= Gtk::ListBox.new.tap do |box|
        box.selection_mode = :none
        box.add_css_class('boxed-list')
      end
    end

    def rows = @rows ||= @managers.map { |manager| DocumentRow.new(manager) }
  end
end
