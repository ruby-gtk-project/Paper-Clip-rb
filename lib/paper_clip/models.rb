# frozen_string_literal: true

# The half of the port that does not touch the widget toolkit: the PDF
# parser and writer, the standard security handler, the XMP packet, the
# enum-to-string tables, the off-main-loop worker and the window state enum.
#
# Keeping these behind one require is what lets the spec suite load them on a
# machine with no display. Everything here requires glib2 or gio2 at most;
# nothing here requires gtk4 or adwaita.
require_relative "translations"
require_relative "pdf_crypt"
require_relative "pdf_strings"
require_relative "xmp_packet"
require_relative "thread_manager"
require_relative "window_state"
require_relative "document"
require_relative "document_manager"
