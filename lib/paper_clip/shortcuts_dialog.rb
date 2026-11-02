# frozen_string_literal: true

require 'adwaita'

module PaperClip
  # ShortcutsDialog lists the keyboard shortcuts.
  #
  # Ported from upstream's src/gtk/shortcut-window.ui, which is a
  # GtkShortcutsWindow with a General group and an Editor group. That widget
  # is deprecated in GTK 4.18, so this port builds the same two groups as an
  # Adwaita shortcuts dialog instead; the shortcuts themselves are upstream's,
  # and every one of them is bound by this port.
  class ShortcutsDialog < Adwaita::ShortcutsDialog
    SECTIONS = {
      'General' => [
        ['Quit', '<control>q'],
        ['New window', '<control>n'],
        ['Close window', '<control>w'],
        ['Open menu', 'F10'],
        ['Keyboard Shortcuts', '<control>question'],
      ],
      'Editor'  => [
        ['Open', '<control>o'],
        ['Save', '<control>s'],
        ['Save As…', '<control><shift>s'],
        ['Add a keyword', '<control>Return'],
      ],
    }.freeze

    def initialize
      super()
      self.title = 'Keyboard Shortcuts'
    end

    def build
      tap do |dialog|
        SECTIONS.each { |title, items| dialog.add(section(title, items)) }
      end
    end

    private

      def section(title, items)
        Adwaita::ShortcutsSection.new.tap do |section|
          section.title = title
          items.each { |label, accelerator| section.add(item(label, accelerator)) }
        end
      end

    # Positional, not keyword, arguments — even though the error a no-argument
    # new raises advertises the signatures as "title: utf8, accelerator: utf8".
      def item(label, accelerator) = Adwaita::ShortcutsItem.new(label, accelerator)
  end
end
