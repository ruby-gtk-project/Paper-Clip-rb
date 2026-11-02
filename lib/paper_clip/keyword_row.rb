# frozen_string_literal: true

require 'adwaita'

require_relative 'translations'

module PaperClip
  # KeywordRow is one editable keyword.
  #
  # Ported from upstream's src/KeywordRow.vala: an entry row with a delete
  # button as its prefix. Upstream's row holds the document and deletes
  # itself by looking its own text up in the keyword list; this one takes
  # callbacks instead, and hands itself to them, so the list that owns the row
  # resolves the row to an index at the moment of the edit. Two rows can hold
  # identical text while they are being typed, and deleting by text would then
  # remove the wrong one; an index captured when the row was built would be
  # wrong as soon as an earlier keyword is deleted.
  class KeywordRow < Adwaita::EntryRow
    include Translations

    # Upstream's own bundled icon, shipped by this port under
    # data/icons/hicolor/scalable/actions/cross-symbolic.svg.
    DELETE_ICON = 'cross-symbolic'

    def initialize(keyword, on_edit, on_delete)
      super()
      self.title = _('Keyword')
      self.text = keyword.to_s
      self.focusable = true
      add_prefix(delete_button)
      signal_connect('notify::text') { on_edit.call(self, text) }
      delete_button.signal_connect('clicked') { on_delete.call(self) }
    end

    def delete_button
      @delete_button ||= Gtk::Button.new.tap do |button|
        button.icon_name = DELETE_ICON
        button.tooltip_text = _('Delete Keyword')
        button.valign = :center
        button.add_css_class('flat')
      end
    end
  end
end
