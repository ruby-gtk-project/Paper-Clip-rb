# frozen_string_literal: true

require 'adwaita'

require_relative 'translations'

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
  #
  # The leading underscores are Alt-key mnemonics and they are inside the
  # translatable string, because a translator picks a mnemonic that works in
  # their language. Marked at definition, translated when the menu is built.
  module PrimaryMenu
    include Translations

    SECTIONS = [
      [[N_('_New Window'), 'app.new-window', nil]],
      [
        [N_('_Save'), 'win.save', '<control>s'],
        [N_('Save _As…'), 'win.save-as', '<control><shift>s'],
        [N_('Open _With…'), 'win.open-with', nil],
      ],
      [
        [N_('_Keyboard Shortcuts'), 'app.shortcuts', nil],
        [N_('_About Paper Clip'), 'app.about', nil],
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
      Gio::MenuItem.new(_(label), action).tap do |entry|
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
