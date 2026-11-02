# frozen_string_literal: true

require 'adwaita'

module PaperClip
  # DocumentRow is one unsaved document in the save-changes dialog, with a
  # checkbox deciding whether it gets saved.
  #
  # Ported from PaperClip.DocumentRow at the foot of upstream's
  # src/SaveChangesDialog.vala: the document's title as the row title, its
  # filename as the subtitle, and the checkbox checked by default so the
  # dialog's Save button saves everything unless something is unticked.
  #
  # I had changed what this dialog calls each document — falling back to the
  # filename when /Title is empty — and I did not propose the change upstream,
  # so this port and the app it is a port of disagreed about what a user sees
  # at the one moment they are deciding whether to lose their edits. The row
  # now shows document.title exactly as upstream's does, blank row and all,
  # and the fallback is written down as a proposal in FINDINGS.md instead of
  # being shipped as though it had been agreed.
  class DocumentRow < Adwaita::ActionRow
    attr_reader :manager

    def initialize(manager)
      super()
      @manager = manager
      self.title = row_title
      self.subtitle = basename
      self.activatable_widget = check_button
      add_prefix(check_button)
      check_button.active = true
    end

    def selected? = check_button.active?

    def check_button
      @check_button ||= Gtk::CheckButton.new.tap { |button| button.valign = :center }
    end

    private

      def document = @manager.document
      def basename = ::File.basename(document.path)

      def row_title = document.title
  end
end
