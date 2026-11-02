# frozen_string_literal: true

require 'adwaita'

require_relative 'string_array_row'
require_relative 'translations'

module PaperClip
  # DetailsList is the read-only half of the editor: the PDF properties that
  # are describing the file rather than annotating it.
  #
  # Ported from upstream's src/DetailsList.vala and src/gtk/details-list.ui —
  # a boxed list of seven property rows plus the two expandable string-array
  # rows, in upstream's order.
  #
  # The page-count row is hidden when the count is zero, as upstream's
  # document setter does (src/DetailsList.vala:61-66). A PDF whose page tree
  # this port cannot follow therefore says nothing about how many pages it
  # has, rather than claiming it has none.
  class DetailsList
    include Translations

    # Marked at definition, translated when the rows are built.
    TITLES = {
      format:      N_('Format'),
      layout:      N_('Layout'),
      duplex:      N_('Duplex'),
      subtype:     N_('Subtype'),
      javascript:  N_('Contains JavaScript'),
      attachments: N_('Contains Attachments'),
      pages:       N_('Number of Pages'),
    }.freeze

    YES = N_('Yes')
    NO = N_('No')

    def build
      list_box.tap do |box|
        action_rows.each_value { |row| box.append(row) }
        box.append(preferences_row)
        box.append(permissions_row)
      end
    end

    def update(document)
      action_rows[:format].subtitle = document.format
      action_rows[:layout].subtitle = document.layout
      action_rows[:duplex].subtitle = document.print_duplex
      action_rows[:subtype].subtitle = document.subtype
      action_rows[:javascript].subtitle = yes_no(document.contains_javascript?)
      action_rows[:attachments].subtitle = yes_no(document.contains_attachments?)
      show_page_count(document.n_pages)
      preferences_row.strings = document.viewer_preferences
      permissions_row.strings = document.permissions
    end

    def list_box
      @list_box ||= Gtk::ListBox.new.tap do |box|
        box.valign = :start
        box.selection_mode = :none
        box.add_css_class('boxed-list')
      end
    end

    # One memoized hash rather than seven near-identical methods: the rows
    # differ only by their title, and the titles are the table above.
    def action_rows
      @action_rows ||= TITLES.transform_values { |title| action_row(_(title)) }
    end

    def preferences_row = @preferences_row ||= StringArrayRow.new(_('Viewer Preferences'))
    def permissions_row = @permissions_row ||= StringArrayRow.new(_('Permissions'))

    private

      def action_row(title)
        Adwaita::ActionRow.new.tap do |row|
          row.title = title
          row.selectable = false
          row.add_css_class('property')
        end
      end

      # The subtitle is only set when there is a count to show, so a hidden
      # row never carries a stale "0" to be revealed by a later document.
      def show_page_count(count)
        action_rows[:pages].tap do |row|
          row.visible = count.positive?
          if row.visible?
            row.subtitle = count.to_s
          end
        end
      end

      def yes_no(flag)
        if flag
          _(YES)
        else
          _(NO)
        end
      end
  end
end
