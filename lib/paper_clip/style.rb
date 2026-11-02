# frozen_string_literal: true

require 'adwaita'

module PaperClip
  # Style is the application stylesheet.
  #
  # A direct port of upstream's src/style.css, which upstream loads from its
  # gresource bundle. There is no gresource here, so the CSS travels as a
  # string and goes onto the default display at the priority application
  # stylesheets use — above the Adwaita theme, below inline styles.
  #
  # `.long-filename` shrinks the filename heading when the name is long;
  # `.overlay-drag-area` is the tinted rectangle the drop overlay reveals
  # while a file is being dragged over the window; the `stack:drop(active)`
  # rule suppresses the focus ring GTK would otherwise draw on the stack
  # that owns the drop target.
  module Style
    CSS = <<~CSS
      .long-filename {
        font-size: 140%;
      }

      stack:drop(active) {
        box-shadow: none;
      }

      .overlay-drag-area {
        border-radius: 8px;
        margin: 24px;
        background-color: alpha(@accent_color, 0.35);
      }
    CSS

    def self.apply
      Gtk::StyleContext.add_provider_for_display(
        Gdk::Display.default,
        provider,
        Gtk::StyleProvider::PRIORITY_APPLICATION,
      )
    end

    def self.provider
      Gtk::CssProvider.new.tap { |css| css.load_from_data(CSS) }
    end
  end
end
