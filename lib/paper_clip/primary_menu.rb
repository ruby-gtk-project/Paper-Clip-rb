# frozen_string_literal: true

require 'adwaita'

module PaperClip
  # PrimaryMenu is the menu behind the hamburger button in the header bar.
  #
  # A direct port of the <menu id="primary_menu"> in upstream's src/window.ui:
  # three sections — the new window, the document actions, then the about and
  # shortcuts pair.
  #
  # The document actions carry hidden-when="action-disabled", which is why
  # Save, Save As and Open With are absent from the menu until a document is
  # open rather than sitting there greyed out. The window enables the three
  # actions once a document loads.
  module PrimaryMenu
    SECTIONS = [
      [['_New Window', 'app.new-window', nil]],
      [
        ['_Save', 'win.save', '<control>s'],
        ['Save _As…', 'win.save-as', '<control><shift>s'],
        ['Open _With…', 'win.open-with', nil],
      ],
      [
        ['_Keyboard Shortcuts', 'app.shortcuts', nil],
        ['_About Paper Clip', 'app.about', nil],
      ],
    ].freeze

    HIDDEN_WHEN_DISABLED = ['win.save', 'win.save-as', 'win.open-with'].freeze

    def self.build
      Gio::Menu.new.tap do |menu|
        SECTIONS.each { |items| menu.append_section(nil, section(items)) }
      end
    end

    def self.section(items)
      Gio::Menu.new.tap do |section|
        items.each { |label, action, accel| section.append_item(item(label, action, accel)) }
      end
    end

    def self.item(label, action, accel)
      Gio::MenuItem.new(label, action).tap do |entry|
        if accel
          entry.set_attribute_value('accel', GLib::Variant.new(accel))
        end
        if HIDDEN_WHEN_DISABLED.include?(action)
          entry.set_attribute_value('hidden-when', GLib::Variant.new('action-disabled'))
        end
      end
    end
  end
end
