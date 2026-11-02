# frozen_string_literal: true

require 'adwaita'

require_relative 'translations'

module PaperClip
  # ShortcutsDialog lists the keyboard shortcuts.
  #
  # Ported from upstream's src/gtk/shortcut-window.ui, which is a
  # GtkShortcutsWindow with a General group and an Editor group. That widget
  # is deprecated in GTK 4.18, so this port builds the same two groups as an
  # Adwaita shortcuts dialog instead; the shortcuts themselves are upstream's,
  # and every one of them is bound by this port.
  #
  # Every string carries msgctxt "shortcut window", as upstream's
  # `context="shortcut window"` does on all ten of them
  # (src/gtk/shortcut-window.ui:11-68). The (msgctxt, msgid) pair is the
  # catalogue key, so dropping the context would make these ten new messages
  # that none of the eighteen languages has a translation for.
  #
  # Two rows of upstream's .ui have no counterpart here, and both are
  # properties of the widget rather than content:
  #
  # * `max-height = 10` (shortcut-window.ui:8) is a GtkShortcutsSection
  #   property. Adw.ShortcutsSection has only item-type, n-items and title —
  #   the dialog sizes and paginates itself — so there is nothing to set.
  # * the dialog's own title is libadwaita's, from its own catalogue, where
  #   upstream's GtkShortcutsWindow also titled itself. Setting one here
  #   would be a new user-visible string with no upstream counterpart.
  class ShortcutsDialog < Adwaita::ShortcutsDialog
    include Translations

    # Upstream's msgctxt is 'shortcut window', and it is written out as a
    # literal at every call site rather than held in a constant: rxgettext
    # resolves p_() only when both arguments are literals, so a constant here
    # would keep the ten keys out of the .pot however correct the runtime
    # lookup looked.

    def build
      tap do |dialog|
        dialog.add(general_section)
        dialog.add(editor_section)
      end
    end

    def general_section
      @general_section ||= section(
        p_('shortcut window', 'General'),
        [
          [p_('shortcut window', 'Quit'), '<control>q'],
          [p_('shortcut window', 'New window'), '<control>n'],
          [p_('shortcut window', 'Close window'), '<control>w'],
          [p_('shortcut window', 'Keyboard Shortcuts'), '<control>question'],
        ],
      )
    end

    def editor_section
      @editor_section ||= section(
        p_('shortcut window', 'Editor'),
        [
          [p_('shortcut window', 'Open'), '<control>o'],
          [p_('shortcut window', 'Save'), '<control>s'],
          [p_('shortcut window', 'Save As…'), '<control><shift>s'],
          [p_('shortcut window', 'Add a keyword'), '<control>Return'],
        ],
      )
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
