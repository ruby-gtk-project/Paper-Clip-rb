# frozen_string_literal: true

require 'adwaita'

require_relative 'keyword_row'

module PaperClip
  # KeywordList is the Keywords group of the editor: one row per keyword, an
  # add button in the group header, and an add-a-keyword row standing in for
  # the list while it is empty.
  #
  # Ported from upstream's src/KeywordList.vala and src/gtk/keyword-list.ui.
  # Upstream binds the list box straight to the document's keyword ListModel;
  # this port's Document keeps its keywords as a plain array, so the rows are
  # rebuilt from it whenever the number of keywords changes. Editing a row
  # does not rebuild — that would pull the cursor out from under the typing.
  #
  # The add button hides while the list is empty, as upstream's does: the
  # empty-state row is itself the thing you click to add the first keyword, so
  # two add affordances would be showing at once.
  class KeywordList
    TITLE = 'Keywords'
    EMPTY_LABEL = 'Add Keyword'
    ADD_ICON = 'list-add-symbolic'
    ACTION_GROUP = 'keyword-list'
    ADD_ACTION = 'add-keyword'
    ADD_ACCELERATOR = '<Control>Return'

    def initialize
      @document = nil
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
      refresh
    end

    def group
      @group ||= Adwaita::PreferencesGroup.new.tap { |group| group.title = TITLE }
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
        button.tooltip_text = 'Add a keyword'
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

    def shortcut_controller
      @shortcut_controller ||= Gtk::ShortcutController.new.tap do |controller|
        controller.add_shortcut(
          Gtk::Shortcut.new(
            Gtk::ShortcutTrigger.parse_string(ADD_ACCELERATOR),
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
      @empty_state_label ||= Gtk::Label.new(EMPTY_LABEL).tap do |label|
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
            refresh
            list_box.last_child&.grab_focus
          end
        end
      end

      def on_row_activated(row)
        if row == empty_state_row
          add_keyword
        end
      end

      def refresh
        clear_rows
        if @document.keywords.empty?
          list_box.append(empty_state_row)
        else
          @document.keywords.each_with_index { |keyword, index| list_box.append(keyword_row(keyword, index)) }
        end
        add_button.visible = !@document.keywords.empty?
      end

      def clear_rows
        while list_box.first_child
          list_box.remove(list_box.first_child)
        end
      end

      def keyword_row(keyword, index)
        KeywordRow.new(
          keyword,
          ->(text) { @document.update_keyword(index, text) },
          -> { delete_keyword(index) },
        )
      end

      def delete_keyword(index)
        @document.remove_keyword_at(index)
        refresh
      end
  end
end
