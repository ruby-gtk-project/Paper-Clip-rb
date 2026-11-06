# frozen_string_literal: true

# Drives the whole app headlessly: builds the application, opens the welcome
# page, loads a real PDF off disk, edits every kind of row in the editor,
# drives the keyword list, the date rows, the details list, the drop target,
# the password dialog against a genuinely encrypted file, the save-changes
# dialog, the shortcuts dialog, the about dialog, the primary menu and the
# second window — and screenshots each state.
#
# Why this file exists: a GTK app that loads is not a GTK app that works.
# `ruby -c` passes on code that builds an empty window, and the Ruby bindings
# differ from the C API in ways that only a run reveals. The first run of this
# script found that GtkDropTarget's "drop" signal hands its handler a
# GLib::Value and not the Gio::File inside it, which meant dropping a PDF on
# the window raised NoMethodError and the drag-and-drop half of the app had
# never worked for anyone.
#
# Run it from the repository root:
#
#   nix develop --command xvfb-run -a ruby test/drive_paper_clip.rb
#
# GTK4 here has no offscreen backend — gtk_init fails outright with no
# display — so xvfb-run is not optional on this machine.
#
# The specs under spec/ cover the display-free half: the PDF parser, the
# standard security handler, the XMP packet and the enum tables. What is
# driven here is what needs a widget.

require "fileutils"
require "tmpdir"

# Scratch directories, so a run never reads or writes the real ones.
SCRATCH = Dir.mktmpdir("paper-clip-drive")
ENV["XDG_CONFIG_HOME"] = File.join(SCRATCH, "config")
ENV["XDG_CACHE_HOME"] = File.join(SCRATCH, "cache")

$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))

require "paper_clip"
require_relative "../spec/support/pdf_fixtures"
require_relative "gtk_driver"

SHOTS = File.expand_path("../tmp/shots", __dir__)
FileUtils.rm_rf(SHOTS)

FIXTURES = File.expand_path("../spec/fixtures", __dir__)

# The PDFs this run opens. The plain ones are generated, because their byte
# offsets have to agree with their own cross-reference tables; the encrypted
# one is committed, because generating it would mean implementing the half of
# the standard security handler the port does not have.
CLASSIC = PdfFixtures.classic(File.join(SCRATCH, "classic.pdf"))
WITH_XMP = PdfFixtures.with_xmp(File.join(SCRATCH, "with-xmp.pdf"))
PAGELESS = PdfFixtures.pageless(File.join(SCRATCH, "pageless.pdf"))
# Copied out of spec/fixtures, because the save path below writes the open
# document back to the file it came from and a drive run must not rewrite a
# committed fixture.
ENCRYPTED = File.join(SCRATCH, "encrypted-aes128.pdf").tap do |path|
  FileUtils.cp(File.join(FIXTURES, "encrypted-aes128.pdf"), path)
end
ENCRYPTED_PASSWORD = "secret"

# A long name with spaces wraps; a long name without any is ellipsised. Both
# thresholds are upstream's and both are driven below.
WRAPPING_NAME = PdfFixtures.classic(
  File.join(SCRATCH, "a document with a remarkably long and spacious name indeed.pdf"),
)
ELLIPSIS_NAME = PdfFixtures.classic(File.join(SCRATCH, "averylongunbrokenfilename.pdf"))

NOT_A_PDF = File.join(SCRATCH, "notes.txt").tap { |path| File.write(path, "not a pdf\n") }

def file_for(path) = Gio::File.new_for_path(path)

# GtkDropTarget's "drop" signal carries a GValue, which is what a real drag
# delivers too, so the drop is emitted exactly as GTK emits it rather than by
# calling the window's handler directly.
def drop_value(path) = GLib::Value.new(Gio::File.gtype, file_for(path))

# The child the "open" steps run. GApplication's open path is only reachable
# through GTK's own emission, which means through a real `run` with file
# arguments, which means a process of its own: this one builds the
# application the way exe/paper-clip does, lets it settle, prints what it
# ended up with and quits.
CHILD = File.join(SCRATCH, "open_child.rb").tap do |path|
  File.write(path, <<~CHILD)
    $LOAD_PATH.unshift(#{File.expand_path("../lib", __dir__).inspect})
    require "tmpdir"
    ENV["XDG_CONFIG_HOME"] = Dir.mktmpdir
    require "paper_clip"

    PaperClip::Application.new(app_id: ARGV.shift).then do |app|
      app.build
      # 2000ms was tight on a loaded box for the two-document case below,
      # which spins up two windows and parses two PDFs before this fires;
      # 5000ms gives it room without slowing the common one-document case,
      # since the timeout is cancelled the moment it runs either way.
      GLib::Timeout.add(5000) do
        app.windows.each do |window|
          puts "WINDOW\\t#{'#'}{window.view_stack.visible_child_name}\\t" \\
               "#{'#'}{window.document_manager.document&.basename}"
        end
        app.app.quit
        false
      end
      app.run(["paper-clip"] + ARGV)
    end
  CHILD
end

# A fresh application id per invocation, so a child never finds a sibling on
# the session bus and hands its files to that one instead of opening them.
def run_child(*paths)
  "#{PaperClip::Application::APP_ID}.Child#{Process.clock_gettime(Process::CLOCK_MONOTONIC, :nanosecond)}"
    .then do |app_id|
      IO.popen([RbConfig.ruby, CHILD, app_id, *paths], err: [:child, :out])
        .then { |io| io.read.tap { io.close } }
        .then { |output| report_from(output) }
    end
end

def report_from(output)
  output.lines.grep(/^WINDOW\t/).map { |line| line.chomp.split("\t", 3) }.then do |rows|
    {
      windows: rows.length,
      pages:   rows.map { |row| row[1] },
      docs:    rows.map { |row| row[2].to_s.empty? ? nil : row[2] },
      stderr:  output,
    }
  end
end

# The GtkButton AdwAlertDialog built for one of its responses, found by the
# label it was given. There is no API for it: the buttons are internal to the
# dialog's own template.
def response_button(dialog, label)
  descendants(dialog).grep(Gtk::Button).find { |button| button.label == label }
end

def descendants(widget)
  [].tap do |all|
    child = widget.first_child
    while child
      all << child
      all.concat(descendants(child))
      child = child.next_sibling
    end
  end
end

application = PaperClip::Application.new

# 500ms (the driver's default) was enough on an idle machine but flaked under
# load: Document.open runs the parse on ThreadManager's worker and reports
# back through GLib::Idle, and a step that checks the result one tick later
# sometimes ran before that idle callback had been dispatched, failing a
# check that had nothing wrong with it. 1500ms gives the worker thread enough
# wall-clock headroom on a loaded box.
GtkDriver.drive(application, shots: SHOTS, interval: 1500) do |d, app|
  d.window { app.windows.first.window }

  # Shorthands. `app.windows` is the application's own list, so these follow
  # whichever window the actions under test created.
  main = -> { app.windows.first }
  view = -> { main.call.document_view }
  manager = -> { main.call.document_manager }
  doc = -> { manager.call.document }

  # --- The welcome page --------------------------------------------------

  d.step("the application builds and opens one window on the welcome page") do
    d.check("one Window was opened") { app.windows.length == 1 }
    d.check("its widget is an Adwaita::ApplicationWindow") do
      main.call.window.is_a?(Adwaita::ApplicationWindow)
    end
    d.check("it is the only toplevel") { Gtk::Window.list_toplevels.length == 1 }
    d.check("its title is Paper Clip") { main.call.window.title == "Paper Clip" }
    d.check("the stack shows the empty page") do
      main.call.view_stack.visible_child_name == PaperClip::Window::EMPTY_PAGE
    end
    d.check("the welcome heading is set") { main.call.welcome_title.label == "Open a Document" }
    d.check("the welcome subtitle is set") do
      main.call.welcome_subtitle.label == "Drag and drop a PDF file here"
    end
    d.check("the welcome icon is the application icon") do
      main.call.welcome_icon.icon_name == PaperClip::Window::APP_ICON
    end
    d.check("the welcome icon is presentational") do
      main.call.welcome_icon.accessible_role == :presentation
    end
    d.check("the progress bar is invisible but present") { main.call.progress_bar.opacity.zero? }
    d.check("the open button carries win.open") { main.call.open_button.action_name == "win.open" }
    d.check("the open button is labelled Open") { main.call.open_button_content.label == "Open" }
    d.check("the menu button has a model") { !main.call.menu_button.menu_model.nil? }
    d.shot("01-welcome")
  end

  d.step("the five bundled icons and the application icon are in the theme") do
    Gtk::IconTheme.get_for_display(Gdk::Display.default).then do |theme|
      [
        "cross-symbolic", "entry-clear-symbolic", "key-symbolic",
        "chain-link-symbolic", "rich-text-symbolic",
      ].each do |name|
        d.check("the icon theme resolves #{name}") { theme.has_icon?(name) }
      end
      d.check("the icon theme resolves the application icon") do
        theme.has_icon?(PaperClip::Application::APP_ID)
      end
      d.check("the icon theme resolves the symbolic application icon") do
        theme.has_icon?("#{PaperClip::Application::APP_ID}-symbolic")
      end
    end
  end

  d.step("the stylesheet is on the display") do
    d.check("the CSS carries the long-filename rule") do
      PaperClip::Style::CSS.include?(".long-filename")
    end
    d.check("the CSS carries the drag tint") { PaperClip::Style::CSS.include?(".overlay-drag-area") }
    d.check("a provider loads the CSS without a parsing error") do
      PaperClip::Style.provider.is_a?(Gtk::CssProvider)
    end
  end

  # --- Actions, accelerators and the primary menu -------------------------

  d.step("every action upstream declares exists, with upstream's accelerators") do
    PaperClip::Application::ACTIONS.each do |name, accels|
      d.check("app.#{name} is registered") { app.app.has_action?(name) }
      accels.each do |accel|
        d.check("app.#{name} is bound to #{accel}") do
          app.app.get_accels_for_action("app.#{name}").include?(accel)
        end
      end
    end
    PaperClip::Window::ACTIONS.each do |name|
      d.check("win.#{name} is registered") { main.call.actions.key?(name) }
    end
    d.check("open is enabled with no document") { main.call.actions["open"].enabled? }
    d.check("main-menu is enabled with no document") { main.call.actions["main-menu"].enabled? }
    PaperClip::Window::DOCUMENT_ACTIONS.each do |name|
      d.check("win.#{name} is disabled with no document") { !main.call.actions[name].enabled? }
    end
  end

  d.step("the window's own shortcut controller holds upstream's three") do
    main.call.shortcut_controller.then do |controller|
      d.check("three shortcuts") { controller.n_items == 3 }
      PaperClip::Window::SHORTCUTS.each do |accelerator, action|
        d.check("#{accelerator} triggers #{action}") do
          (0...controller.n_items).map { |i| controller.get_item(i) }.any? do |shortcut|
            shortcut.trigger == Gtk::ShortcutTrigger.new(accelerator) &&
              shortcut.action.action_name == action
          end
        end
      end
    end
  end

  d.step("the primary menu is upstream's three sections") do
    PaperClip::PrimaryMenu.build.then do |menu|
      d.check("three sections") { menu.n_items == 3 }
      d.check("every item names a real action") do
        PaperClip::PrimaryMenu::SECTIONS.flatten(1).all? do |_label, action, _accel|
          group, name = action.split(".")
          group == "app" ? app.app.has_action?(name) : main.call.actions.key?(name)
        end
      end
      d.check("the three document items are hidden while disabled") do
        PaperClip::PrimaryMenu::HIDDEN_WHEN_DISABLED.sort ==
          ["win.open-with", "win.save", "win.save-as"]
      end
    end
  end

  d.step("the main-menu action pops the menu button open") do
    main.call.actions["main-menu"].activate(nil)
  end

  d.step("the menu is showing") do
    d.check("the menu button is active") { main.call.menu_button.active? }
    d.shot("02-primary-menu")
    main.call.menu_button.popdown
  end

  # --- The shortcuts dialog ----------------------------------------------

  d.step("app.shortcuts opens the shortcuts dialog") do
    app.app.activate_action("shortcuts", nil)
  end

  d.step("it lists upstream's two sections and eight shortcuts") do
    main.call.window.visible_dialog.then do |dialog|
      d.check("a shortcuts dialog is showing") { dialog.is_a?(PaperClip::ShortcutsDialog) }
      d.check("the General section is titled") { dialog.general_section.title == "General" }
      d.check("General holds four items") { dialog.general_section.n_items == 4 }
      d.check("the Editor section is titled") { dialog.editor_section.title == "Editor" }
      d.check("Editor holds four items") { dialog.editor_section.n_items == 4 }
      d.shot("03-shortcuts", dialog)
      dialog.close
    end
  end

  # --- The about dialog --------------------------------------------------

  d.step("app.about opens the about dialog") do
    app.app.activate_action("about", nil)
  end

  d.step("it carries the name, version and a usable debug block") do
    main.call.window.visible_dialog.then do |dialog|
      d.check("an about dialog is showing") { dialog.is_a?(Adwaita::AboutDialog) }
      d.check("it names the application") { dialog.application_name == "Paper Clip" }
      d.check("it carries the version") { dialog.version == PaperClip::AboutDialog::VERSION }
      d.check("it names upstream's developer") do
        dialog.developers.include?("Diego Iván M.E")
      end
      d.check("it names upstream's artist") { dialog.artists.include?("Brage Fuglseth") }
      d.check("the debug block prints a real Gtk version") do
        dialog.debug_info.match?(/^Gtk \d+\.\d+\.\d+ \(Runtime\)$/)
      end
      d.check("the debug block prints a real Libadwaita version") do
        dialog.debug_info.match?(/^Libadwaita \d+\.\d+\.\d+ \(Runtime\)$/)
      end
      d.check("the debug block prints a real GdkPixbuf version") do
        dialog.debug_info.match?(/^GdkPixbuf \d+\.\d+\.\d+ \(Runtime\)$/)
      end
      d.check("the debug block prints a real Poppler version") do
        dialog.debug_info.match?(/^Poppler \d+\.\d+/)
      end
      d.shot("04-about", dialog)
      dialog.close
    end
  end

  # --- Loading a document ------------------------------------------------

  d.step("a PDF handed in on the command line loads") do
    main.call.open_command_line_file(file_for(CLASSIC))
  end

  d.step("the editor page is showing with every field filled in") do
    d.check("a document is open") { !doc.call.nil? }
    d.check("the stack swapped to the editor") do
      main.call.view_stack.visible_child_name == PaperClip::Window::EDITOR_PAGE
    end
    d.check("the document actions are enabled now") do
      PaperClip::Window::DOCUMENT_ACTIONS.all? { |name| main.call.actions[name].enabled? }
    end
    d.check("the filename is the heading") { view.call.title_label.label == "classic.pdf" }
    d.check("the title row took /Title") { view.call.entry_rows[:title].text == "Secret Title" }
    d.check("the author row took /Author") { view.call.entry_rows[:author].text == "Ada Lovelace" }
    d.check("the creator row took /Creator") { view.call.entry_rows[:creator].text == "Hand" }
    d.check("the producer row took /Producer") { view.call.entry_rows[:producer].text == "Hand" }
    d.check("the subject row is empty, as the file is") do
      view.call.entry_rows[:subject].text == ""
    end
    d.check("the window title tracks the document title") do
      main.call.window.title == "Secret Title"
    end
    d.check("the progress bar faded back out") { main.call.progress_bar.opacity < 1 }
    d.check("nothing is dirty on a fresh load") { !manager.call.changed? }
  end

  d.step("the editor renders") { d.shot("05-editor") }

  d.step("the thumbnail of page one arrived from Poppler") do
    d.check("the document hands out page one") { !doc.call.get_page_for_index(0).nil? }
    d.check("the image has a paintable") { !view.call.document_thumbnail.image.paintable.nil? }
    d.check("the bin wraps the image") do
      view.call.document_thumbnail.bin.child.equal?(view.call.document_thumbnail.image)
    end
    d.check("the thumbnailer was given the display size") do
      PaperClip::Thumbnailer.default.max_size == PaperClip::DocumentThumbnail::MAX_SIZE
    end
    d.check("its memory format matches this machine's byte order") do
      PaperClip::Thumbnailer.default.default_format ==
        ([1].pack("S") == [1].pack("v") ? :b8g8r8a8_premultiplied : :a8r8g8b8_premultiplied)
    end
  end

  d.step("the date rows took the dates the file records") do
    d.check("the creation date row is not empty") do
      view.call.creation_row.subtitle != "No date set"
    end
    d.check("it is the date in the Info dictionary") do
      view.call.creation_row.date.to_i == Time.new(2024, 1, 15, 10, 30, 0, "+00:00").to_i
    end
    d.check("the modification row has no date, as the file has none") do
      view.call.modification_row.date.nil? &&
        view.call.modification_row.subtitle == "No date set"
    end
  end

  d.step("the non-editable properties are filled in") do
    view.call.details_list.then do |list|
      d.check("the format is read off the header") { list.action_rows[:format].subtitle == "PDF-1.7" }
      d.check("the layout row has a subtitle") { !list.action_rows[:layout].subtitle.to_s.empty? }
      d.check("the duplex row has a subtitle") { !list.action_rows[:duplex].subtitle.to_s.empty? }
      d.check("the subtype row has a subtitle") { !list.action_rows[:subtype].subtitle.to_s.empty? }
      d.check("JavaScript reads No") { list.action_rows[:javascript].subtitle == "No" }
      d.check("Attachments reads No") { list.action_rows[:attachments].subtitle == "No" }
      d.check("the page count row is showing") { list.action_rows[:pages].visible? }
      d.check("it reads the one page the file declares") do
        list.action_rows[:pages].subtitle == "1"
      end
      d.check("the permissions row lists the file's permissions") do
        !list.permissions_row.content_row.content_label.label.empty?
      end
      d.check("each permission is bulleted") do
        list.permissions_row.content_row.content_label.label.start_with?("• ")
      end
    end
  end

  d.step("the permissions expander opens") do
    view.call.details_list.permissions_row.expanded = true
  end

  d.step("it is expanded and its text is readable") do
    view.call.details_list.then do |list|
      d.check("the row reports itself expanded") { list.permissions_row.expanded? }
      d.check("the content row is unselectable") { !list.permissions_row.content_row.selectable? }
      d.check("the viewer preferences row exists too") do
        list.preferences_row.is_a?(PaperClip::StringArrayRow)
      end
      d.shot("06-details-expanded")
      list.permissions_row.expanded = false
    end
  end

  # --- Editing ------------------------------------------------------------

  d.step("typing in the title row writes through to the document") do
    view.call.entry_rows[:title].text = "Edited Title"
  end

  d.step("the document and the window title both followed") do
    d.check("the document took the new title") { doc.call.title == "Edited Title" }
    d.check("the manager is dirty now") { manager.call.changed? }
    d.check("the window title followed") { main.call.window.title == "Edited Title" }
  end

  d.step("every other editable row writes through too") do
    { author: "Grace Hopper", subject: "Driving", creator: "Harness", producer: "Harness" }
      .each do |field, value|
        view.call.entry_rows[field].text = value
        d.check("the document took the new #{field}") { doc.call.public_send(field) == value }
      end
  end

  d.step("picking a day in the calendar keeps the clock the PDF recorded") do
    view.call.creation_row.calendar.day = 16
  end

  d.step("the date moved and the time of day survived") do
    view.call.creation_row.date.then do |date|
      d.check("the day moved to the 16th") { date.day == 16 }
      d.check("the hour survived") { date.hour == 10 }
      d.check("the minute survived") { date.min == 30 }
      d.check("the document took it") { doc.call.creation_date.day == 16 }
      d.check("the subtitle was rewritten") { view.call.creation_row.subtitle == date.strftime("%x") }
    end
  end

  d.step("the Today and Tomorrow buttons set dates a day apart") do
    view.call.modification_row.then do |row|
      row.today_button.signal_emit("clicked")
      Time.now.then do |now|
        d.check("Today set today") { row.date.to_date == now.to_date } if row.date.respond_to?(:to_date)
        d.check("Today set a date") { !row.date.nil? }
        d.check("Today's date is within a minute of now") { (row.date.to_i - now.to_i).abs < 60 }
      end
      row.date.then do |today|
        row.tomorrow_button.signal_emit("clicked")
        d.check("Tomorrow is a day later") { (row.date.to_i - today.to_i) == PaperClip::DateRow::DAY }
      end
      d.check("the document took the modification date") { !doc.call.modification_date.nil? }
    end
  end

  d.step("the clear button empties the row and the document") do
    view.call.modification_row.clear_button.signal_emit("clicked")
  end

  d.step("the date is gone from both") do
    d.check("the row has no date") { view.call.modification_row.date.nil? }
    d.check("it says so") { view.call.modification_row.subtitle == "No date set" }
    d.check("the document has none either") { doc.call.modification_date.nil? }
  end

  # --- Keywords -----------------------------------------------------------

  d.step("the keyword list came up with the file's two keywords") do
    view.call.keyword_list.then do |list|
      d.check("the group is titled Keywords") { list.group.title == "Keywords" }
      d.check("two keyword rows") { list.list_box.children.count { |r| r.is_a?(PaperClip::KeywordRow) } == 2 }
      d.check("they are the file's keywords") do
        list.list_box.children.grep(PaperClip::KeywordRow).map(&:text) == ["alpha", "beta"]
      end
      d.check("the add button is showing with a non-empty list") { list.add_button.visible? }
      d.check("the add button carries the list's action") do
        list.add_button.action_name == "keyword-list.add-keyword"
      end
      d.check("the empty-state row is not in the list") do
        !list.list_box.children.include?(list.empty_state_row)
      end
    end
  end

  d.step("the add action appends an empty keyword row") do
    view.call.keyword_list.add_action.activate(nil)
  end

  d.step("there are three rows and three keywords") do
    view.call.keyword_list.then do |list|
      d.check("three keyword rows") { list.list_box.children.grep(PaperClip::KeywordRow).length == 3 }
      d.check("the document has three keywords") { doc.call.keywords.length == 3 }
      d.check("the new one is empty") { doc.call.keywords.last == "" }
    end
  end

  d.step("typing into the new row names the keyword") do
    view.call.keyword_list.list_box.children.grep(PaperClip::KeywordRow).last.text = "gamma"
  end

  d.step("the document took it, by index and not by text") do
    d.check("three keywords still") { doc.call.keywords.length == 3 }
    d.check("the third is gamma") { doc.call.keywords == ["alpha", "beta", "gamma"] }
    d.shot("07-keywords")
  end

  d.step("the middle row's delete button removes exactly that keyword") do
    view.call.keyword_list.list_box.children.grep(PaperClip::KeywordRow)[1]
        .delete_button.signal_emit("clicked")
  end

  d.step("beta went and the neighbours survived") do
    view.call.keyword_list.then do |list|
      d.check("two keywords left") { doc.call.keywords == ["alpha", "gamma"] }
      d.check("two rows left") { list.list_box.children.grep(PaperClip::KeywordRow).length == 2 }
      d.check("the surviving rows hold the surviving text") do
        list.list_box.children.grep(PaperClip::KeywordRow).map(&:text) == ["alpha", "gamma"]
      end
    end
  end

  d.step("deleting the rest brings the empty-state row back") do
    view.call.keyword_list.list_box.children.grep(PaperClip::KeywordRow)
        .each { |row| row.delete_button.signal_emit("clicked") }
  end

  d.step("the list is empty and offers to add the first keyword") do
    view.call.keyword_list.then do |list|
      d.check("no keywords") { doc.call.keywords.empty? }
      d.check("no keyword rows") { list.list_box.children.grep(PaperClip::KeywordRow).empty? }
      d.check("the empty-state row is in the list") do
        list.list_box.children.include?(list.empty_state_row)
      end
      d.check("it is activatable") { list.empty_state_row.activatable? }
      d.check("it reads Add Keyword") { list.empty_state_label.label == "Add Keyword" }
      d.check("the add button hid itself") { !list.add_button.visible? }
      d.shot("08-keywords-empty")
    end
  end

  d.step("activating the empty-state row adds the first keyword") do
    view.call.keyword_list.then do |list|
      list.list_box.signal_emit("row-activated", list.empty_state_row)
    end
  end

  d.step("the list has a row again and the empty state went") do
    view.call.keyword_list.then do |list|
      d.check("one keyword") { doc.call.keywords.length == 1 }
      d.check("one row") { list.list_box.children.grep(PaperClip::KeywordRow).length == 1 }
      d.check("the empty-state row is gone") do
        !list.list_box.children.include?(list.empty_state_row)
      end
      d.check("the add button is back") { list.add_button.visible? }
    end
  end

  d.step("the Ctrl+Return shortcut reaches the same action") do
    view.call.keyword_list.shortcut_controller.then do |controller|
      d.check("one shortcut") { controller.n_items == 1 }
      d.check("it is Ctrl+Return") do
        controller.get_item(0).trigger ==
          Gtk::ShortcutTrigger.new(PaperClip::KeywordList::ADD_ACCELERATOR)
      end
      d.check("and it names the add action") do
        controller.get_item(0).action.action_name == "keyword-list.add-keyword"
      end
    end
  end

  d.step("the editor's own two shortcuts are the save pair") do
    view.call.shortcut_controller.then do |controller|
      d.check("two shortcuts") { controller.n_items == 2 }
      PaperClip::DocumentView::SHORTCUTS.each do |accelerator, action|
        d.check("#{accelerator} triggers #{action}") do
          (0...controller.n_items).map { |i| controller.get_item(i) }.any? do |shortcut|
            shortcut.trigger == Gtk::ShortcutTrigger.new(accelerator) &&
              shortcut.action.action_name == action
          end
        end
      end
    end
  end

  # --- Saving -------------------------------------------------------------

  d.step("the save action writes the edits back to the file") do
    d.check("there are edits to save") { manager.call.changed? }
    main.call.actions["save"].activate(nil)
  end

  d.step("the file on disk carries the new title and the flag is clean") do
    d.check("the manager is clean again") { !manager.call.changed? }
    d.check("the saved file holds the edited title") do
      File.binread(CLASSIC).include?("Edited Title")
    end
    d.check("the saved file holds the edited author") do
      File.binread(CLASSIC).include?("Grace Hopper")
    end
    d.check("the progress bar came back down") { main.call.progress_bar.opacity < 1 }
  end

  d.step("a save to another path is what Save As hands the manager") do
    File.join(SCRATCH, "saved-as.pdf").then do |target|
      manager.call.save(target, on_done: -> { @saved_as = target })
    end
  end

  d.step("the copy is on disk and reads back") do
    d.check("the file was written") { !@saved_as.nil? && File.exist?(@saved_as) }
    d.check("it is a PDF") { File.binread(@saved_as).start_with?("%PDF-") }
    d.check("it holds the edited title") { File.binread(@saved_as).include?("Edited Title") }
    d.check("Open With is enabled and has a document to hand over") do
      main.call.actions["open-with"].enabled? && !doc.call.original_file.nil?
    end
  end

  # --- The drop target ----------------------------------------------------

  d.step("the drop overlay is assembled and idle") do
    main.call.drop_overlay.then do |overlay|
      d.check("the bin wraps the overlay") { overlay.bin.child.equal?(overlay.overlay) }
      d.check("the overlay's child is the view stack") do
        overlay.overlay.child.equal?(main.call.view_stack)
      end
      d.check("the revealer is invisible while idle") { !overlay.revealer.visible? }
      d.check("it cannot be targeted") { !overlay.revealer.can_target? }
      d.check("the tint is not applied") do
        !main.call.overlay_bin.has_css_class?(PaperClip::DropOverlay::DRAG_CLASS)
      end
    end
  end

  # current-drop is read-only on GtkDropTarget, so there is no way to make GTK
  # publish a drag from here; the handler is invoked with a stand-in that
  # answers the one property it reads.
  d.step("a drag in progress reveals the tint") do
    Struct.new(:current_drop).new(:a_drop).then do |dragging|
      main.call.drop_overlay.send(:on_current_drop, dragging)
    end
  end

  d.step("the overlay is revealed and tinted") do
    main.call.drop_overlay.then do |overlay|
      d.check("the revealer is visible") { overlay.revealer.visible? }
      d.check("and revealing its child") { overlay.revealer.reveal_child? }
      d.check("the tint is on the overlaid bin") do
        main.call.overlay_bin.has_css_class?(PaperClip::DropOverlay::DRAG_CLASS)
      end
      d.shot("09-drag-tint")
    end
  end

  d.step("the drag ending hides it again") do
    main.call.drop_overlay.send(:on_current_drop, Struct.new(:current_drop).new(nil))
  end

  d.step("the overlay is idle again") do
    main.call.drop_overlay.then do |overlay|
      d.check("the revealer is invisible") { !overlay.revealer.visible? }
      d.check("the tint is gone") do
        !main.call.overlay_bin.has_css_class?(PaperClip::DropOverlay::DRAG_CLASS)
      end
    end
  end

  d.step("dropping something that is not a PDF is refused") do
    @refused = main.call.drop_target.signal_emit("drop", drop_value(NOT_A_PDF), 0.0, 0.0)
  end

  d.step("the refusal left the open document alone") do
    d.check("the drop was declined") { @refused == false }
    d.check("the document did not change") { doc.call.basename == "classic.pdf" }
    d.check("the editor is still showing") do
      main.call.view_stack.visible_child_name == PaperClip::Window::EDITOR_PAGE
    end
  end

  d.step("dropping a PDF is accepted") do
    @accepted = main.call.drop_target.signal_emit("drop", drop_value(WITH_XMP), 0.0, 0.0)
  end

  d.step("the dropped file is the open document now") do
    d.check("the drop was accepted") { @accepted == true }
    d.check("the dropped file loaded") { doc.call.basename == "with-xmp.pdf" }
    d.check("the heading is the dropped file's name") do
      view.call.title_label.label == "with-xmp.pdf"
    end
    d.check("the document found its XMP packet") { doc.call.has_xmp? }
    d.check("the page count is the two the file declares") do
      view.call.details_list.action_rows[:pages].subtitle == "2"
    end
    d.check("the keyword rows were rebuilt for the new document") do
      view.call.keyword_list.list_box.children.grep(PaperClip::KeywordRow).map(&:text) ==
        ["alpha", "beta"]
    end
    d.shot("10-dropped")
  end

  # --- The empty and awkward states ---------------------------------------

  d.step("a PDF whose page tree says nothing hides the page-count row") do
    main.call.drop_target.signal_emit("drop", drop_value(PAGELESS), 0.0, 0.0)
  end

  d.step("the row is hidden rather than claiming no pages") do
    view.call.details_list.then do |list|
      d.check("the pageless file is open") { doc.call.basename == "pageless.pdf" }
      d.check("it reports no pages") { doc.call.n_pages.zero? }
      d.check("the page-count row is hidden") { !list.action_rows[:pages].visible? }
      # Upstream's else branch hides the row and leaves its subtitle alone
      # (src/DetailsList.vala:66), so a previous document's count can still
      # be in there; what neither upstream nor this port ever does is show a
      # count of zero.
      d.check("it never claims zero pages") { list.action_rows[:pages].subtitle != "0" }
      d.check("the keyword list came up with this file's keywords") do
        view.call.keyword_list.list_box.children.grep(PaperClip::KeywordRow).map(&:text) ==
          ["alpha", "beta"]
      end
      d.shot("11-pageless")
    end
  end

  d.step("a long spacious filename gets the wrapping class") do
    main.call.drop_target.signal_emit("drop", drop_value(WRAPPING_NAME), 0.0, 0.0)
  end

  d.step("the heading wraps instead of shrinking off the edge") do
    view.call.title_label.then do |label|
      d.check("the long-filename class is on") do
        label.has_css_class?(PaperClip::DocumentView::LONG_FILENAME_CLASS)
      end
      d.check("it is not ellipsised") { label.ellipsize == :none }
      d.check("the label wraps") { label.wrap? }
      d.shot("12-long-filename")
    end
  end

  d.step("a long unbroken filename is ellipsised instead") do
    main.call.drop_target.signal_emit("drop", drop_value(ELLIPSIS_NAME), 0.0, 0.0)
  end

  d.step("the heading ellipsises and drops the wrapping class") do
    view.call.title_label.then do |label|
      d.check("it is ellipsised at the end") { label.ellipsize == :end }
      d.check("the long-filename class came off") do
        !label.has_css_class?(PaperClip::DocumentView::LONG_FILENAME_CLASS)
      end
    end
  end

  # --- The password dialog ------------------------------------------------

  d.step("an encrypted PDF asks for its password") do
    main.call.drop_target.signal_emit("drop", drop_value(ENCRYPTED), 0.0, 0.0)
  end

  d.step("the password dialog is up and names the file") do
    main.call.window.visible_dialog.then do |dialog|
      d.check("a password dialog is showing") { dialog.is_a?(PaperClip::PasswordDialog) }
      d.check("it says the document is encrypted") do
        dialog.status_page.title == "This Document Is Encrypted"
      end
      d.check("it names the file it is asking about") do
        dialog.status_page.description == File.basename(ENCRYPTED)
      end
      d.check("the entry is a password row") do
        dialog.password_row.is_a?(Adwaita::PasswordEntryRow)
      end
      d.check("the Decrypt button carries the success action") do
        dialog.decrypt_button.action_name == "dialog.success"
      end
      d.check("Return and Escape are captured, not bubbled") do
        dialog.shortcut_controller.propagation_phase == :capture
      end
      d.check("both are bound") { dialog.shortcut_controller.n_items == 2 }
      d.check("the editor still shows the last good document") do
        view.call.title_label.label == "averylongunbrokenfilename.pdf"
      end
      d.shot("13-password", dialog)
    end
  end

  d.step("a wrong password is refused") do
    main.call.window.visible_dialog.tap do |dialog|
      dialog.password_row.text = "not it"
      dialog.success_action.activate(nil)
    end
  end

  # The failed load runs on ThreadManager's worker and reports back through
  # GLib::Idle, so the refusal needs a turn of the loop of its own before the
  # toast it raises can be looked for.
  d.step("waiting for the refused load to report back") { nil }

  d.step("the refusal is a toast and not a load") do
    d.check("the dialog closed") { main.call.window.visible_dialog.nil? }
    d.check("a toast was raised") { !main.call.last_toast.nil? }
    d.check("it is upstream's incorrect-password message") do
      main.call.last_toast.title ==
        "Failed to open the document. The provided password is incorrect."
    end
    d.check("the encrypted file did not become the open document") do
      doc.call.basename == "averylongunbrokenfilename.pdf"
    end
    d.shot("14-password-refused")
  end

  d.step("asking again and cancelling leaves everything alone") do
    main.call.drop_target.signal_emit("drop", drop_value(ENCRYPTED), 0.0, 0.0)
  end

  d.step("the dialog is up again") do
    d.check("a password dialog is showing") do
      main.call.window.visible_dialog.is_a?(PaperClip::PasswordDialog)
    end
    main.call.window.visible_dialog.cancel_action.activate(nil)
  end

  d.step("the cancellation closed the dialog and opened nothing") do
    d.check("the dialog closed") { main.call.window.visible_dialog.nil? }
    d.check("the document is unchanged") do
      doc.call.basename == "averylongunbrokenfilename.pdf"
    end
  end

  d.step("asking a third time, to answer it correctly") do
    main.call.drop_target.signal_emit("drop", drop_value(ENCRYPTED), 0.0, 0.0)
  end

  d.step("the right password is accepted") do
    main.call.window.visible_dialog.tap do |dialog|
      dialog.password_row.text = ENCRYPTED_PASSWORD
      dialog.success_action.activate(nil)
    end
  end

  d.step("the encrypted document is open and decrypted") do
    d.check("the dialog closed") { main.call.window.visible_dialog.nil? }
    d.check("the encrypted file is the open document") do
      doc.call.basename == File.basename(ENCRYPTED)
    end
    d.check("its Info dictionary was decrypted") { doc.call.title == "Secret Title" }
    d.check("and its author too") { doc.call.author == "Ada Lovelace" }
    d.check("the title row shows the decrypted title") do
      view.call.entry_rows[:title].text == "Secret Title"
    end
    d.check("its keywords were decrypted") { doc.call.keywords == ["alpha", "beta"] }
    d.check("the editor is showing") do
      main.call.view_stack.visible_child_name == PaperClip::Window::EDITOR_PAGE
    end
  end

  # The shot waits a tick. A window whose content changed in this tick has not
  # been laid out again yet, and Gtk::WidgetPaintable then produces no render
  # node at all rather than a stale picture.
  d.step("the decrypted editor renders") { d.shot("15-decrypted") }

  # --- The save-changes interruption --------------------------------------

  d.step("an unsaved edit, so the interruption has something to protect") do
    view.call.entry_rows[:subject].text = "Unsaved"
  end

  d.step("the open action raises the save-changes dialog instead of a chooser") do
    d.check("there is an unsaved edit") { manager.call.changed? }
    main.call.actions["open"].activate(nil)
  end

  d.step("the dialog lists the one unsaved document") do
    main.call.window.visible_dialog.then do |dialog|
      d.check("an alert dialog is showing") { dialog.is_a?(Adwaita::AlertDialog) }
      d.check("it asks upstream's question") { dialog.heading == "Save Changes?" }
      d.check("its body is upstream's warning") do
        dialog.body.start_with?("Open documents contain unsaved changes")
      end
      d.check("Save is the default response") { dialog.default_response == "save" }
      d.check("Cancel is the close response") { dialog.close_response == "cancel" }
      d.check("Discard is destructive") do
        dialog.get_response_appearance("discard") ==
          Adwaita::ResponseAppearance::DESTRUCTIVE
      end
      d.check("Save is suggested") do
        dialog.get_response_appearance("save") == Adwaita::ResponseAppearance::SUGGESTED
      end
      d.shot("16-save-changes", dialog)
    end
  end

  d.step("the row in it names the document and is ticked by default") do
    app.windows.first.then do |window|
      PaperClip::DocumentRow.new(window.document_manager).then do |row|
        d.check("the row title is the document's own title") do
          row.title == doc.call.title
        end
        d.check("its subtitle is the filename") { row.subtitle == doc.call.basename }
        d.check("it is ticked") { row.selected? }
        d.check("the checkbox is the row's activatable widget") do
          row.activatable_widget.equal?(row.check_button)
        end
        row.check_button.active = false
        d.check("unticking it deselects the document") { !row.selected? }
      end
    end
  end

  # adw_alert_dialog_response() is not bound — AdwAlertDialog exposes
  # add_response and get_response_appearance but no plain `response` — and
  # the two halves cannot be faked, because adw_dialog_close() on an alert
  # dialog emits the close response on its way out: emitting "save" and then
  # closing fires "cancel" straight afterwards, and the port's state machine
  # correctly reads that as "never mind", so the window it was told to close
  # stays open.
  #
  # So the response is given the way a user gives it: by clicking the button.
  # AdwAlertDialog builds one GtkButton per response, labelled with the
  # response's own label, and clicking it emits exactly one response and
  # closes the dialog.
  answer = lambda do |window, response|
    window.window.visible_dialog.then do |dialog|
      response_button(dialog, dialog.get_response_label(response))
        .signal_emit("clicked")
    end
  end

  d.step("cancelling the dialog abandons the open and keeps the edit") do
    answer.call(main.call, "cancel")
  end

  d.step("nothing was lost") do
    d.check("the dialog went") { main.call.window.visible_dialog.nil? }
    d.check("the edit is still unsaved") { manager.call.changed? }
    d.check("the document is still the encrypted one") do
      doc.call.basename == File.basename(ENCRYPTED)
    end
  end

  # --- A second window ----------------------------------------------------

  # Opened before the first window is closed below, because closing the last
  # window of a GApplication ends the main loop and would take the rest of
  # the run with it.
  d.step("the new-window action opens another window") do
    app.app.activate_action("new-window", nil)
  end

  d.step("the second window is a fresh welcome page") do
    d.check("two Windows are registered") { app.windows.length == 2 }
    d.check("two toplevels") { Gtk::Window.list_toplevels.length == 2 }
    app.windows.last.then do |second|
      d.check("it is a window of its own") { !second.window.equal?(app.windows.first.window) }
      d.check("it starts on the welcome page") do
        second.view_stack.visible_child_name == PaperClip::Window::EMPTY_PAGE
      end
      d.check("it has no document") { second.document_manager.document.nil? }
      d.check("nothing is unsaved in it") { !second.document_manager.changed? }
      d.check("its document actions start disabled") do
        PaperClip::Window::DOCUMENT_ACTIONS.none? { |name| second.actions[name].enabled? }
      end
      d.check("its open action is enabled all the same") { second.actions["open"].enabled? }
      d.check("it is titled Paper Clip") { second.window.title == "Paper Clip" }
      d.check("a clean window lets close-request through") do
        second.window.signal_emit("close-request") == false
      end
      d.shot("17-second-window", second.window)
    end
  end

  # --- Closing a window with unsaved work ---------------------------------

  d.step("closing the first window with unsaved work raises the dialog too") do
    @closing = main.call
    @close_blocked = @closing.window.signal_emit("close-request")
  end

  d.step("the close was blocked and the dialog is up") do
    d.check("close-request was refused") { @close_blocked == true }
    d.check("the window is still here") { Gtk::Window.list_toplevels.length == 2 }
    d.check("the save-changes dialog is showing") do
      @closing.window.visible_dialog.is_a?(Adwaita::AlertDialog)
    end
    d.shot("18-closing", @closing.window)
  end

  d.step("answering Save writes the document out and lets the close through") do
    answer.call(@closing, "save")
  end

  d.step("the save landed") do
    d.check("the manager is clean") { !@closing.document_manager.changed? }
    # The document is encrypted, so the edit is not on disk in the clear:
    # re-opening it under the same password is the only way to read it back,
    # and it is the round trip worth pinning anyway.
    d.check("the edit reads back out of the saved file") do
      PaperClip::Document.new(file_for(ENCRYPTED), ENCRYPTED_PASSWORD).subject == "Unsaved"
    end
    d.check("the file is still a PDF") { File.binread(ENCRYPTED).start_with?("%PDF-") }
  end

  d.step("and the window went on closing") do
    d.check("the window closed once the work was safe") do
      !Gtk::Window.list_toplevels.include?(@closing.window)
    end
    d.check("the application dropped it from its list") { app.windows.length == 1 }
    d.check("the second window is the survivor") { !app.windows.first.equal?(@closing) }
    d.check("and it is still on its welcome page") do
      app.windows.first.view_stack.visible_child_name == PaperClip::Window::EMPTY_PAGE
    end
  end

  # --- Refusals and the quit path -----------------------------------------

  # g_application_open cannot be reached from Ruby at all: calling it raises
  # NotImplementedError out of gobject-introspection 4.3.9 ("TODO: in Ruby ->
  # GIArgument(array/C)[interface(interface)](GFile)") and emitting the "open"
  # signal by hand segfaults the process in the same marshaller. GTK's own
  # emission — the one the desktop and the command line use — converts the
  # GFile array into Ruby correctly, so the open path is driven the only way
  # it can be: a child process that runs the application with file arguments
  # and reports back what it opened.
  d.step("a PDF on the command line opens in a window of its own") do
    @opened = run_child(CLASSIC)
  end

  d.step("the child opened the PDF") do
    d.check("the child ran and reported") { !@opened.nil? }
    d.check("it opened exactly one window") { @opened[:windows] == 1 }
    d.check("that window holds the file it was given") { @opened[:docs] == ["classic.pdf"] }
    d.check("and it is on the editor page") { @opened[:pages] == ["editor"] }
  end

  d.step("a file that is not a PDF is refused rather than opened") do
    @refused_open = run_child(NOT_A_PDF)
  end

  d.step("the child refused it and fell back to an empty window") do
    d.check("the child ran and reported") { !@refused_open.nil? }
    d.check("it still opened one window, as activate does") { @refused_open[:windows] == 1 }
    d.check("but no document was loaded into it") { @refused_open[:docs] == [nil] }
    d.check("so it is sitting on the welcome page") { @refused_open[:pages] == ["empty"] }
    d.check("and it said why on stderr") do
      @refused_open[:stderr].include?("is not a PDF")
    end
  end

  d.step("two PDFs on the command line open one window each") do
    @two = run_child(CLASSIC, WITH_XMP)
  end

  d.step("the child opened both") do
    d.check("two windows") { @two[:windows] == 2 }
    d.check("one document each") do
      @two[:docs].sort == ["classic.pdf", "with-xmp.pdf"]
    end
    d.check("both on the editor page") { @two[:pages].uniq == ["editor"] }
  end

  # has_action? asserts the application is registered, so an application that
  # has never run cannot be queried that way; lookup_action is the ActionMap
  # call that works before registration. A separate id keeps this probe from
  # colliding with the application this run is driving.
  d.step("the quit path with nothing unsaved does not stop to ask") do
    PaperClip::Application.new(app_id: "#{PaperClip::Application::APP_ID}.Probe").then do |fresh|
      fresh.build
      d.check("it has no windows and so nothing unsaved") { fresh.windows.empty? }
      PaperClip::Application::ACTIONS.each_key do |name|
        d.check("app.#{name} is on it before it ever registers") do
          !fresh.app.lookup_action(name).nil?
        end
      end
      fresh.app.activate_action("query-quit", nil)
      d.check("no dialog was raised, because nothing was unsaved") do
        app.windows.none? { |window| window.window.visible_dialog }
      end
      d.check("this run's own application is still going") { Gtk::Window.list_toplevels.any? }
    end
  end

  # --- The display-free edges the editor depends on ------------------------

  d.step("the state machine's four states are upstream's") do
    d.check("four states") { PaperClip::WindowState::ALL.length == 4 }
    d.check("they are upstream's") do
      PaperClip::WindowState::ALL ==
        [:none, :opening_file, :closing, :opening_dropped]
    end
  end

  d.step("the command-line options are registered with their descriptions") do
    d.check("two options") { PaperClip::Main::OPTIONS.length == 2 }
    d.check("--new-window is one of them") do
      PaperClip::Main::OPTIONS.any? { |name, letter, _| name == "new-window" && letter == "w" }
    end
    d.check("--version is the other") do
      PaperClip::Main::OPTIONS.any? { |name, letter, _| name == "version" && letter == "v" }
    end
    d.check("--new-window is routed through gapplication-action") do
      PaperClip::Main.action_arguments(["-w"]) == ["--gapplication-action=new-window"]
    end
    d.check("nothing is routed without it") { PaperClip::Main.action_arguments([]).empty? }
    d.check("the flags are stripped from the remaining arguments") do
      PaperClip::Main.remaining(["-w", "a.pdf", "--version"]) == ["a.pdf"]
    end
    d.check("add_options registers both on a GApplication") do
      Gtk::Application.new("io.github.diegoivan.pdf_metadata_editor.Probe", :default_flags)
                      .then { |probe| PaperClip::Main.add_options(probe) || true }
    end
  end

  d.step("the worker thread delivers its results on the main loop") do
    PaperClip::ThreadManager.run_in_thread(on_done: ->(value) { @threaded = value }) { 6 * 7 }
  end

  d.step("the result arrived") do
    d.check("the block ran on the worker and came back") { @threaded == 42 }
  end

  d.step("Poppler is loaded through its typelib and answers for itself") do
    d.check("it reports a version") { PaperClip::AboutDialog.poppler_version.match?(/\A\d+\.\d+/) }
    d.check("it opens a PDF by URI") do
      !Poppler.open(file_for(CLASSIC).uri).nil?
    end
    d.check("and reports the page it has") { Poppler.open(file_for(CLASSIC).uri).n_pages == 1 }
  end

  d.step("the translation machinery is bound and answers") do
    d.check("an unknown string comes back unchanged") do
      PaperClip::Translations.instance_method(:_).bind(view.call).call("Open") == "Open"
    end
    d.check("a contexted lookup falls back to its msgid") do
      PaperClip::Translations.instance_method(:p_)
                             .bind(view.call).call("shortcut window", "Quit") == "Quit"
    end
  end

  d.step("the editor's action group namespace is in place") do
    d.check("it is a SimpleActionGroup") do
      view.call.action_group.is_a?(Gio::SimpleActionGroup)
    end
    # g_action_group_list_actions is not bound, so emptiness is asserted the
    # way it matters: the group shadows none of the window actions the
    # editor's own shortcuts point at, so Ctrl+S reaches win.save.
    d.check("and shadows none of the window's actions, as upstream's empty one does") do
      PaperClip::Window::ACTIONS.none? { |name| view.call.action_group.has_action?(name) }
    end
    d.check("the scroller starts at the top of a freshly loaded document") do
      view.call.scroller.vadjustment.value.zero?
    end
  end
end
