# frozen_string_literal: true

require 'adwaita'

require_relative 'keyword_row'
require_relative 'translations'

module PaperClip
  # KeywordList is the Keywords group of the editor: one row per keyword, an
  # add button in the group header, and an add-a-keyword row standing in for
  # the list while it is empty.
  #
  # Ported from upstream's src/KeywordList.vala and src/gtk/keyword-list.ui.
  # Upstream binds the list box to the document's keyword ListModel and
  # connects items-changed (KeywordList.vala:37-39); this port's Document
  # keeps its keywords as a plain array and publishes the same notification
  # through on_keywords_changed, with the same (position, removed, added)
  # triple. The rows are then edited in place rather than rebuilt: deleting
  # one keyword while typing into another must not throw away the widget that
  # has the cursor in it.
  #
  # The add button hides while the list is empty, as upstream's is_empty
  # property makes it: the empty-state row is itself the thing you click to
  # add the first keyword, so two add affordances would be showing at once.
  class KeywordList
    include Translations

    ADD_ICON = 'list-add-symbolic'
    ACTION_GROUP = 'keyword-list'
    ADD_ACTION = 'add-keyword'
    ADD_ACCELERATOR = '<Control>Return'

    def initialize
      @document = nil
      @rows = []
      @empty_state_shown = false
    end

    def build
      group.tap do |g|
        g.header_suffix = add_button
        g.add(list_box)
        g.insert_action_group(ACTION_GROUP, action_group)
        g.add_controller(shortcut_controller)

        list_box.signal_connect('row-activated') { |_, row| on_row_activated(row) }
      end
    end

    def update(document)
      @document = document
      document.on_keywords_changed { |position, removed, added| on_items_changed(position, removed, added) }
      rebuild
    end

    def group
      @group ||= Adwaita::PreferencesGroup.new.tap { |group| group.title = _('Keywords') }
    end

    def list_box
      @list_box ||= Gtk::ListBox.new.tap do |box|
        box.selection_mode = :none
        box.add_css_class('boxed-list')
      end
    end

    def add_button
      @add_button ||= Gtk::Button.new.tap do |button|
        button.icon_name = ADD_ICON
        button.tooltip_text = _('Add a keyword')
        button.action_name = "#{ACTION_GROUP}.#{ADD_ACTION}"
        button.add_css_class('flat')
      end
    end

    # The add is an action rather than a plain handler so the Ctrl+Return
    # shortcut below and the header button can both reach it, which is how
    # upstream wires it too.
    def action_group
      @action_group ||= Gio::SimpleActionGroup.new.tap { |group| group.add_action(add_action) }
    end

    def add_action
      @add_action ||= Gio::SimpleAction.new(ADD_ACTION, nil).tap do |action|
        action.signal_connect('activate') { add_keyword }
      end
    end

    # Gtk::ShortcutTrigger.new and not .parse_string: these bindings expose
    # gtk_shortcut_trigger_parse_string as the class's only constructor, so the
    # accelerator string goes to `new` and the named method does not exist.
    def shortcut_controller
      @shortcut_controller ||= Gtk::ShortcutController.new.tap do |controller|
        controller.add_shortcut(
          Gtk::Shortcut.new(
            Gtk::ShortcutTrigger.new(ADD_ACCELERATOR),
            Gtk::NamedAction.new("#{ACTION_GROUP}.#{ADD_ACTION}"),
          ),
        )
      end
    end

    # The empty-state row: an add icon on the left, the label centred, the
    # whole row activatable.
    def empty_state_row
      @empty_state_row ||= Adwaita::PreferencesRow.new.tap do |row|
        row.activatable = true
        row.selectable = false
        row.child = empty_state_box
      end
    end

    def empty_state_box
      @empty_state_box ||= Gtk::CenterBox.new.tap do |box|
        box.start_widget = empty_state_icon
        box.center_widget = empty_state_label
      end
    end

    def empty_state_icon
      @empty_state_icon ||= Gtk::Image.new(icon_name: ADD_ICON).tap do |image|
        image.halign = :end
        image.hexpand = true
        image.margin_end = 12
      end
    end

    def empty_state_label
      @empty_state_label ||= Gtk::Label.new(_('Add Keyword')).tap do |label|
        label.justify = :center
        label.wrap = true
        label.margin_top = 12
        label.margin_bottom = 12
      end
    end

    private

      def add_keyword
        @document.then do |document|
          if document
            document.add_keyword('')
          end
        end
      end

      def on_row_activated(row)
        if row == empty_state_row
          add_keyword
        end
      end

      # A new document replaces the whole list, which is what assigning
      # bind_model's source does upstream.
      def rebuild
        drop_all_rows
        @document.keywords.each_with_index { |keyword, index| insert_row(keyword, index) }
        settle
      end

      # The three arguments are items-changed's: remove exactly the rows that
      # went away, insert exactly the ones that arrived, and leave every
      # other row — and its cursor — alone.
      def on_items_changed(position, removed, added)
        removed.times { remove_row_at(position) }
        added.times { |offset| insert_row(@document.keywords[position + offset], position + offset) }
        settle
      end

      def insert_row(keyword, index)
        keyword_row(keyword).tap do |row|
          @rows.insert(index, row)
          list_box.insert(row, index)
        end
      end

      def remove_row_at(index)
        @rows.delete_at(index).then do |row|
          if row
            list_box.remove(row)
          end
        end
      end

      def drop_all_rows
        @rows.each { |row| list_box.remove(row) }
        @rows = []
      end

      # Upstream's on_items_changed: the empty-state row appears and
      # disappears with the list, the last row takes focus on every change,
      # and the first row takes it when the list has just become one row
      # long (src/KeywordList.vala:63-87).
      def settle
        if @document.keywords.empty?
          show_empty_state
        else
          hide_empty_state
          focus_rows
        end
        add_button.visible = !@document.keywords.empty?
      end

      def focus_rows
        @rows.last&.grab_focus
        if @document.keywords.length == 1
          @rows.first&.grab_focus
        end
      end

      def show_empty_state
        unless @empty_state_shown
          @empty_state_shown = true
          list_box.append(empty_state_row)
        end
      end

      def hide_empty_state
        if @empty_state_shown
          @empty_state_shown = false
          list_box.remove(empty_state_row)
        end
      end

      def keyword_row(keyword)
        KeywordRow.new(
          keyword,
          ->(row, text) { update_keyword(row, text) },
          ->(row) { delete_keyword(row) },
        )
      end

      def update_keyword(row, text)
        @rows.index(row).then do |index|
          if index
            @document.update_keyword(index, text)
          end
        end
      end

      def delete_keyword(row)
        @rows.index(row).then do |index|
          if index
            @document.remove_keyword_at(index)
          end
        end
      end
  end
end
