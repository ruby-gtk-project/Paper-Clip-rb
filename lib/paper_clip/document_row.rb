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
  # Upstream shows the title even when it is empty, which leaves a blank row;
  # a PDF with no /Title is common enough that this falls back to the filename
  # so the row always says which document it is.
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

      def row_title
        document.title.then do |title|
          if title.strip.empty?
            basename
          else
            title
          end
        end
      end
  end
end
