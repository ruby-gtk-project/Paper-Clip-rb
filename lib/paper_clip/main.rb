# frozen_string_literal: true

require 'adwaita'

require_relative 'application'
require_relative 'translations'

module PaperClip
  # Main is the entry point.
  #
  # Ported from upstream's src/main.vala, which is four lines — construct the
  # application and run it — plus the OptionEntry[] table upstream's
  # Application constructor registers (src/application.vala:45-50) and
  # handles in handle_local_options.
  #
  # The two options are registered on the GApplication, so `paper-clip --help`
  # prints them with their descriptions, translated, exactly as upstream's
  # does. They were previously described only in this comment, which meant
  # --help documented neither flag.
  #
  # --version is still answered here rather than in the application's own
  # handler, because it must print without registering with the session bus;
  # --new-window is a request aimed at an instance that may already be
  # running, so it goes through --gapplication-action and raises a window on
  # the first process instead of starting a second one.
  module Main
    include Translations

    VERSION_FLAGS = ['-v', '--version'].freeze
    NEW_WINDOW_FLAGS = ['-w', '--new-window'].freeze

    # name, short letter, description — upstream's table, with upstream's two
    # N_() descriptions.
    OPTIONS = [
      ['new-window', 'w', N_('Open a new window')],
      ['version', 'v', N_('Print version information and exit')],
    ].freeze

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
      Application.new.then do |application|
        application.build
        add_options(application.app)
        application.run(['paper-clip'] + remaining(argv) + action_arguments(argv))
      end
    end

    # GApplication's own --help lists whatever has been added here, which is
    # the only way either flag gets a line in it.
    def self.add_options(app)
      OPTIONS.each do |name, letter, description|
        app.add_main_option(
          name,
          letter.ord,
          GLib::OptionFlags::NONE,
          GLib::OptionArg::NONE,
          _(description),
          nil,
        )
      end
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
