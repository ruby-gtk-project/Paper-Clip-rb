# frozen_string_literal: true

require 'adwaita'

require_relative 'application'

module PaperClip
  # Main is the entry point.
  #
  # Ported from upstream's src/main.vala, which is four lines — construct the
  # application and run it — plus the OptionEntry[] table upstream's
  # Application constructor registers and handles in handle_local_options:
  #
  #   -w, --new-window   Open a new window
  #   -v, --version      Print version information and exit
  #
  # Those two are handled here rather than inside the application, because
  # --version must print without ever registering with the session bus, and
  # --new-window is a request aimed at an instance that is already running:
  # it is passed through as the app.new-window action so a second launch
  # raises a window on the first process instead of starting a new one.
  module Main
    VERSION_FLAGS = ['-v', '--version'].freeze
    NEW_WINDOW_FLAGS = ['-w', '--new-window'].freeze

    def self.run(argv = ARGV)
      if VERSION_FLAGS.any? { |flag| argv.include?(flag) }
        print_version
      else
        start(argv)
      end
    end

    def self.print_version
      warn "Paper Clip #{AboutDialog::VERSION}"
      0
    end

    def self.start(argv)
      Application.new.build.run(['paper-clip'] + remaining(argv) + action_arguments(argv))
    end

    def self.remaining(argv)
      argv.reject { |argument| (NEW_WINDOW_FLAGS + VERSION_FLAGS).include?(argument) }
    end

    # GApplication understands --gapplication-action; routing --new-window
    # through it is what lets the flag reach an instance already running.
    def self.action_arguments(argv)
      if NEW_WINDOW_FLAGS.any? { |flag| argv.include?(flag) }
        ['--gapplication-action=new-window']
      else
        []
      end
    end
  end
end
