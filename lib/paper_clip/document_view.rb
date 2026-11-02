# frozen_string_literal: true

require 'adwaita'

require_relative 'date_row'
require_relative 'details_list'
require_relative 'document_thumbnail'
require_relative 'keyword_list'
require_relative 'translations'

module PaperClip
  # DocumentView is the editor page: a preview of page one, the filename as a
  # heading, the editable metadata, the keyword list, and the non-editable
  # properties below.
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
  # The window title is the ninth of those bindings
  # (src/DocumentView.vala:63), and it is a push rather than a bind for the
  # same reason: the title row's notify::text re-sets it, so the titlebar and
  # the window list track the document's title as it is typed.
  class DocumentView
    include Translations

    # The editable Info fields, in upstream's order, mapped to the Document
    # accessors behind them. Marked at definition, translated at display.
    FIELDS = {
      title:    N_('Title'),
      author:   N_('Author'),
      creator:  N_('Creation Software'),
      subject:  N_('Subject'),
      producer: N_('Conversion Software'),
    }.freeze

    DETAILS_TITLE = N_('Non-Editable Properties')
    LONG_FILENAME_CLASS = 'long-filename'

    # document-view.ui:14 puts this class on the clamp. Upstream defines no
    # rule for it in src/style.css, so it currently styles nothing there
    # either — it is attached here because removing an attachment is not the
    # port's call to make, and the missing rule is reported upstream.
    DROP_CLASS = 'document-view-drop'

    # Upstream inserts an empty SimpleActionGroup under this name
    # (src/DocumentView.vala:77-78). Nothing uses it yet; it is the namespace
    # an editor action would land in.
    ACTION_GROUP = 'editor'

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
        s.insert_action_group(ACTION_GROUP, action_group)

        content_clamp.tap do |clamp|
          clamp.child = content_box

          content_box.tap do |box|
            box.append(document_thumbnail.build)
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
        entry_rows[:title].signal_connect('notify::text') { show_window_title }
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
      show_window_title
      details_list.update(document)
      document_thumbnail.update(document)
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

    def content_clamp
      @content_clamp ||= Adwaita::Clamp.new.tap { |clamp| clamp.add_css_class(DROP_CLASS) }
    end

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
      @details_group ||= Adwaita::PreferencesGroup.new.tap { |group| group.title = _(DETAILS_TITLE) }
    end

    # One memoized hash of entry rows rather than five methods differing only
    # in their title.
    def entry_rows
      @entry_rows ||= FIELDS.transform_values { |title| entry_row(_(title)) }
    end

    def creation_row = @creation_row ||= DateRow.new(_('Creation Date'))
    def modification_row = @modification_row ||= DateRow.new(_('Modification Date'))
    def details_list = @details_list ||= DetailsList.new
    def document_thumbnail = @document_thumbnail ||= DocumentThumbnail.new
    def keyword_list = @keyword_list ||= KeywordList.new

    def action_group = @action_group ||= Gio::SimpleActionGroup.new

    def shortcut_controller
      @shortcut_controller ||= Gtk::ShortcutController.new.tap do |controller|
        SHORTCUTS.each { |accelerator, action| controller.add_shortcut(shortcut(accelerator, action)) }
      end
    end

    private

      def entry_row(title)
        Adwaita::EntryRow.new.tap { |row| row.title = title }
      end

      # Gtk::ShortcutTrigger.new and not .parse_string: these bindings expose
      # gtk_shortcut_trigger_parse_string as the class's only constructor, so
      # the string goes to `new` and the named method does not exist. It
      # raised NoMethodError the first time the page was built.
      def shortcut(accelerator, action)
        Gtk::Shortcut.new(
          Gtk::ShortcutTrigger.new(accelerator),
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

      # Upstream binds document.title straight onto the window's title with
      # SYNC_CREATE, so an untitled PDF leaves the title empty and the window
      # manager falls back to the application name on its own.
      def show_window_title
        scroller.root.then do |root|
          if root
            root.title = entry_rows[:title].text
          end
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

      # Upstream logs when the launcher reports that the user picked nothing
      # (src/DocumentView.vala:129), which is the difference between "no
      # application opened it" and "the user changed their mind".
      def launch(document, parent)
        Gtk::FileLauncher.new(document.original_file).tap do |launcher|
          launcher.always_ask = true
          launcher.launch(parent, nil) do |_, result|
            unless launcher.launch_finish(result)
              warn('File was not opened by the user')
            end
          rescue GLib::Error => e
            warn(e.message)
          end
        end
      end
  end
end
