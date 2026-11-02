# frozen_string_literal: true

require 'adwaita'

module PaperClip
  # DateRow is a row showing a date, with a calendar popover to change it and
  # a button to clear it.
  #
  # Ported from upstream's src/DateRow.vala and src/gtk/date-row.ui: the date
  # as the row subtitle, a clear button and a calendar menu button as
  # suffixes, and Today / Tomorrow shortcuts under the calendar.
  #
  # A nil date is a real state, not a missing one — a PDF may simply carry no
  # /CreationDate — so it reads "No date set" rather than hiding the row.
  #
  # The @syncing flag matters: writing year, month and day onto the calendar
  # to reflect a date set from outside makes GtkCalendar emit day-selected,
  # which would otherwise be read back as the user picking a date and clobber
  # the time of day the PDF recorded.
  class DateRow < Adwaita::ActionRow
    NO_DATE = 'No date set'
    CLEAR_ICON = 'edit-clear-symbolic'
    CALENDAR_ICON = 'x-office-calendar-symbolic'
    DAY = 60 * 60 * 24

    attr_reader :date

    def initialize(title)
      super()
      self.title = title
      @date = nil
      @syncing = false
      @on_change = nil
      self.subtitle = NO_DATE
      add_suffix(clear_button)
      add_suffix(calendar_button)
      clear_button.signal_connect('clicked') { change_date(nil) }
      today_button.signal_connect('clicked') { change_date(Time.now) }
      tomorrow_button.signal_connect('clicked') { change_date(Time.now + DAY) }
    end

    def on_change(&block) = @on_change = block

    # Assignment is the "from the document" direction and deliberately does
    # not call back: only the buttons and the calendar report a change.
    def date=(value)
      @date = value
      if value.nil?
        self.subtitle = NO_DATE
      else
        self.subtitle = value.strftime('%x')
        sync_calendar(value)
      end
    end

    def clear_button
      @clear_button ||= Gtk::Button.new.tap do |button|
        button.icon_name = CLEAR_ICON
        button.tooltip_text = 'Remove Date'
        button.valign = :center
        button.add_css_class('flat')
      end
    end

    def calendar_button
      @calendar_button ||= Gtk::MenuButton.new.tap do |button|
        button.icon_name = CALENDAR_ICON
        button.tooltip_text = 'Show Calendar'
        button.valign = :center
        button.add_css_class('flat')
        button.popover = calendar_popover
      end
    end

    def calendar_popover
      @calendar_popover ||= Gtk::Popover.new.tap { |popover| popover.child = popover_box }
    end

    def popover_box
      @popover_box ||= Gtk::Box.new(:vertical, 6).tap do |box|
        box.append(calendar)
        box.append(shortcut_box)
      end
    end

    def shortcut_box
      @shortcut_box ||= Gtk::Box.new(:horizontal, 0).tap do |box|
        box.homogeneous = true
        box.add_css_class('linked')
        box.append(today_button)
        box.append(tomorrow_button)
      end
    end

    def calendar
      @calendar ||= Gtk::Calendar.new.tap do |cal|
        cal.signal_connect('day-selected') { on_day_selected(cal) }
      end
    end

    def today_button = @today_button ||= Gtk::Button.new(label: 'Today')
    def tomorrow_button = @tomorrow_button ||= Gtk::Button.new(label: 'Tomorrow')

    private

      def on_day_selected(calendar)
        unless @syncing
          change_date(Time.new(calendar.year, calendar.month + 1, calendar.day))
        end
      end

      def change_date(value)
        self.date = value
        @on_change&.call(value)
      end

    # GtkCalendar's month is zero-based; Time's is not.
      def sync_calendar(value)
        @syncing = true
        calendar.year = value.year
        calendar.month = value.month - 1
        calendar.day = value.day
        @syncing = false
      end
  end
end
