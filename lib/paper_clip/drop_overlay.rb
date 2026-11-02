# frozen_string_literal: true

require 'adwaita'

module PaperClip
  # DropOverlay tints the window while a file is being dragged over it.
  #
  # A direct port of upstream's src/DropOverlay.vala: a bin wrapping an
  # overlay, whose overlaid child is a revealer that crossfades in while a
  # drag is in progress. The revealer is not a drop target itself — it sits
  # over the one — so can_target is false, and it stays invisible rather than
  # merely un-revealed so it cannot intercept anything while idle.
  #
  # The tint itself is the .overlay-drag-area class from the stylesheet,
  # applied to the overlaid widget rather than the revealer, exactly as
  # upstream does.
  class DropOverlay
    DRAG_CLASS = 'overlay-drag-area'

    def initialize(child, overlayed)
      @child = child
      @overlayed = overlayed
    end

    def build
      bin.tap do |b|
        b.child = overlay

        overlay.tap do |o|
          o.child = @child
          o.add_overlay(revealer)

          revealer.child = @overlayed
        end
      end
    end

    # Upstream watches the drop target's current-drop property rather than
    # its enter and leave signals, because current-drop also clears when the
    # drag ends somewhere else entirely.
    def drop_target=(target)
      target.signal_connect('notify::current-drop') { on_current_drop(target) }
    end

    def bin = @bin ||= Adwaita::Bin.new
    def overlay = @overlay ||= Gtk::Overlay.new

    def revealer
      @revealer ||= Gtk::Revealer.new.tap do |rev|
        rev.can_target = false
        rev.visible = false
        rev.transition_type = :crossfade
      end
    end

    private

      def on_current_drop(target)
        if target.current_drop
          reveal(true)
          @overlayed.add_css_class(DRAG_CLASS)
        else
          reveal(false)
          @overlayed.remove_css_class(DRAG_CLASS)
        end
      end

      def reveal(flag)
        revealer.visible = flag
        revealer.reveal_child = flag
      end
  end
end
