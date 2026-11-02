# frozen_string_literal: true

require_relative "rb/version"
require_relative "../../paper_clip/models"

# Paper::Clip::Rb is the gem's library entry point, which is what
# spec/spec_helper.rb requires and what `rake spec` therefore needs to exist.
#
# It loads the version and the display-free half of the port: the PDF parser,
# the security handler, the XMP packet, the string tables and the thread
# worker. It deliberately does not load lib/paper_clip.rb, because that pulls
# in gtk4, whose `require` calls gtk_init and raises Gtk::InitError on a
# machine with no display — which is where a test suite runs. The GUI entry
# point is exe/paper-clip, which requires "paper_clip".
module Paper
  module Clip
    module Rb
    end
  end
end
