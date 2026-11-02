# frozen_string_literal: true

require 'adwaita'

module PaperClip
  # WindowState is what the window is in the middle of doing.
  #
  # Ported from the WindowState enum at the foot of upstream's
  # src/window.vala. The state exists because an unsaved document interrupts
  # whatever was asked for: the save-changes dialog runs first, and the state
  # records what to resume once it is answered — open a file, open the file
  # that was dropped, or finish closing the window.
  module WindowState
    NONE = :none
    OPENING_FILE = :opening_file
    CLOSING = :closing
    OPENING_DROPPED = :opening_dropped

    ALL = [NONE, OPENING_FILE, CLOSING, OPENING_DROPPED].freeze
  end
end
