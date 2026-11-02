# frozen_string_literal: true

require 'adwaita'

module PaperClip
  # StringArrayRow is an expander row whose expanded contents are a bulleted
  # list of strings.
  #
  # A direct port of upstream's src/StringArrayRow.vala, which holds both this
  # class and the ContentRow below it. The details list uses two of them, for
  # the viewer preferences and the permissions, because either may be a list
  # of several entries and neither is editable.
  class StringArrayRow < Adwaita::ExpanderRow
    def initialize(title)
      super()
      self.title = title
      self.selectable = false
      add_row(content_row)
    end

    def strings=(list)
      content_row.contents = Array(list).map { |item| "• #{item}\n" }.join
    end

    def content_row = @content_row ||= ContentRow.new
  end

  # ContentRow is the single, unselectable row holding the bulleted text.
  #
  # Ported from PaperClip.ContentRow in the same upstream file: a dim label,
  # start-aligned and inset, which the expander reveals.
  class ContentRow < Gtk::ListBoxRow
    def initialize
      super()
      self.selectable = false
      self.activatable = false
      self.child = content_label
    end

    def contents=(value)
      content_label.label = value.to_s
    end

    def content_label
      @content_label ||= Gtk::Label.new.tap do |label|
        label.add_css_class('dim-label')
        label.halign = :start
        label.margin_start = 12
        label.margin_top = 18
      end
    end
  end
end
