# frozen_string_literal: true

require 'adwaita'

require_relative 'string_array_row'

module PaperClip
  # DetailsList is the read-only half of the editor: the PDF properties that
  # are describing the file rather than annotating it.
  #
  # Ported from upstream's src/DetailsList.vala and src/gtk/details-list.ui —
  # a boxed list of seven property rows plus the two expandable string-array
  # rows, in upstream's order.
  #
  # One deliberate difference: upstream hides the page-count row when the
  # count is zero. Here every row is always shown, because a row that
  # disappears reads as a bug rather than as "this document has no pages".
  class DetailsList
    TITLES = {
      format:      'Format',
      layout:      'Layout',
      duplex:      'Duplex',
      subtype:     'Subtype',
      javascript:  'Contains JavaScript',
      attachments: 'Contains Attachments',
      pages:       'Number of Pages',
    }.freeze

    YES = 'Yes'
    NO = 'No'

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
      action_rows[:pages].subtitle = document.n_pages.to_s
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
      @action_rows ||= TITLES.transform_values { |title| action_row(title) }
    end

    def preferences_row = @preferences_row ||= StringArrayRow.new('Viewer Preferences')
    def permissions_row = @permissions_row ||= StringArrayRow.new('Permissions')

    private

      def action_row(title)
        Adwaita::ActionRow.new.tap do |row|
          row.title = title
          row.selectable = false
          row.add_css_class('property')
        end
      end

      def yes_no(flag)
        if flag
          YES
        else
          NO
        end
      end
  end
end
