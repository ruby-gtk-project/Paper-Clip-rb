# frozen_string_literal: true

require 'adwaita'

require_relative 'date_row'
require_relative 'details_list'
require_relative 'keyword_list'

module PaperClip
  # DocumentView is the editor page: the filename as a heading, the editable
  # metadata, the keyword list, and the non-editable properties below.
  #
  # Ported from upstream's src/DocumentView.vala and
  # src/gtk/document-view.ui, including the Ctrl+S / Ctrl+Shift+S shortcut
  # controller that page carries and the long-filename measuring.
  #
  # Upstream wires the rows to the document with a GObject BindingGroup, two
  # ways and synced on create. This port's Document is plain Ruby, so the
  # binding is explicit: update pushes the document into the rows, and the
  # rows' change signals push back. @loading guards that write-back, because
  # setting row.text to load a document also emits notify::text, and without
  # the guard merely opening a file would mark it as changed.
  #
  # The page-one thumbnail upstream shows above the heading is absent: it
  # needs Poppler to rasterise a page and there is no Poppler binding here.
  class DocumentView
    # The editable Info fields, in upstream's order, mapped to the Document
    # accessors behind them.
    FIELDS = {
      title:    'Title',
      author:   'Author',
      creator:  'Creation Software',
      subject:  'Subject',
      producer: 'Conversion Software',
    }.freeze

    DETAILS_TITLE = 'Non-Editable Properties'
    LONG_FILENAME_CLASS = 'long-filename'

    # Upstream's two thresholds: a long name with spaces in it wraps at a
    # smaller font size, a long name without any has nowhere to wrap and is
    # ellipsised instead.
    WRAPPING_LENGTH = 45
    ELLIPSIS_LENGTH = 21

    SHORTCUTS = {
      '<Control>s'        => 'win.save',
      '<Control><Shift>s' => 'win.save-as',
    }.freeze

    def initialize
      @document = nil
      @loading = false
    end

    def build
      scroller.tap do |s|
        s.child = content_clamp
        s.add_controller(shortcut_controller)

        content_clamp.tap do |clamp|
          clamp.child = content_box

          content_box.tap do |box|
            box.append(title_label)
            box.append(properties_group)
            box.append(keyword_list.build)
            box.append(details_group)

            properties_group.tap do |group|
              entry_rows.each_value { |row| group.add(row) }
              group.add(creation_row)
              group.add(modification_row)
            end

            details_group.tap { |group| group.add(details_list.build) }
          end
        end

        entry_rows.each { |field, row| row.signal_connect('notify::text') { write_field(field, row.text) } }
        creation_row.on_change { |date| write_date(:creation_date=, date) }
        modification_row.on_change { |date| write_date(:modification_date=, date) }
      end
    end

    def update(document)
      @document = document
      @loading = true
      load_rows(document)
      @loading = false
      show_filename(document)
      details_list.update(document)
      keyword_list.update(document)
      entry_rows[:title].grab_focus_without_selecting
      scroller.vadjustment.value = 0
    end

    # The Open With action, which hands the original file to whatever else can
    # open a PDF. always_ask is upstream's setting: the point of the action is
    # to choose an application, not to re-run the default one.
    def open_on_app(parent)
      @document.then do |document|
        if document
          launch(document, parent)
        end
      end
    end

    def scroller
      @scroller ||= Gtk::ScrolledWindow.new.tap do |s|
        s.propagate_natural_height = true
        s.propagate_natural_width = true
      end
    end

    def content_clamp = @content_clamp ||= Adwaita::Clamp.new

    def content_box
      @content_box ||= Gtk::Box.new(:vertical, 18).tap do |box|
        box.margin_start = 12
        box.margin_end = 12
        box.margin_top = 12
        box.margin_bottom = 24
      end
    end

    def title_label
      @title_label ||= Gtk::Label.new.tap do |label|
        label.wrap = true
        label.justify = :center
        label.hexpand = true
        label.add_css_class('title-1')
      end
    end

    def properties_group = @properties_group ||= Adwaita::PreferencesGroup.new

    def details_group
      @details_group ||= Adwaita::PreferencesGroup.new.tap { |group| group.title = DETAILS_TITLE }
    end

    # One memoized hash of entry rows rather than five methods differing only
    # in their title.
    def entry_rows
      @entry_rows ||= FIELDS.transform_values { |title| entry_row(title) }
    end

    def creation_row = @creation_row ||= DateRow.new('Creation Date')
    def modification_row = @modification_row ||= DateRow.new('Modification Date')
    def details_list = @details_list ||= DetailsList.new
    def keyword_list = @keyword_list ||= KeywordList.new

    def shortcut_controller
      @shortcut_controller ||= Gtk::ShortcutController.new.tap do |controller|
        SHORTCUTS.each { |accelerator, action| controller.add_shortcut(shortcut(accelerator, action)) }
      end
    end

    private

      def entry_row(title)
        Adwaita::EntryRow.new.tap { |row| row.title = title }
      end

      def shortcut(accelerator, action)
        Gtk::Shortcut.new(
          Gtk::ShortcutTrigger.parse_string(accelerator),
          Gtk::NamedAction.new(action),
        )
      end

      def load_rows(document)
        entry_rows.each { |field, row| row.text = document.public_send(field) }
        creation_row.date = document.creation_date
        modification_row.date = document.modification_date
      end

      def write_field(field, text)
        unless @loading
          @document&.public_send(:"#{field}=", text)
        end
      end

      def write_date(setter, date)
        unless @loading
          @document&.public_send(setter, date)
        end
      end

      def show_filename(document)
        ::File.basename(document.path).then do |basename|
          title_label.label = basename
          measure_filename(basename)
        end
      end

      def measure_filename(basename)
        title_label.remove_css_class(LONG_FILENAME_CLASS)
        title_label.ellipsize = :none
        if basename.length > WRAPPING_LENGTH && basename.include?(' ')
          title_label.add_css_class(LONG_FILENAME_CLASS)
        elsif basename.length > ELLIPSIS_LENGTH && !basename.include?(' ')
          title_label.ellipsize = :end
        end
      end

      def launch(document, parent)
        Gtk::FileLauncher.new(document.original_file).tap do |launcher|
          launcher.always_ask = true
          launcher.launch(parent, nil) do |_, result|
            launcher.launch_finish(result)
          rescue GLib::Error
            nil
          end
        end
      end
  end
end
