# frozen_string_literal: true

# A stand-in for one of the port's classes, for exercising the markers
# Translations hands out.
#
# It is a named class on purpose. ruby-gettext registers a bound text domain
# against the class that called bindtextdomain and resolves a lookup by
# walking the caller's ancestors; an anonymous `Class.new { include ... }`
# never resolves, and silently returns the msgid instead. Every class in the
# port is named, so this is not a constraint on the app — but it is a trap
# worth leaving a note about, because the failure looks exactly like a missing
# catalogue.
class TranslatedHost
  include PaperClip::Translations

  LABEL = N_("Printing")

  def plain = _("Open a Document")
  def contextual = p_("shortcut window", "Close window")
  def marked_only = N_("Printing")
  def translated_table_entry = _(LABEL)
end
