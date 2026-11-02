# frozen_string_literal: true

require_relative 'translations'

module PaperClip
  # PdfStrings turns the enumerations and bit flags a PDF carries into the
  # human-readable strings the details list shows.
  #
  # Ported from the string tables in upstream's src/Document.vala —
  # layout_to_string, print_duplex_to_string, subtype_to_string,
  # viewer_preferences_to_string_array and permissions_to_string_array.
  # Upstream switches on Poppler enum members; this port reads the PDF
  # dictionaries directly, so the keys here are the PDF names themselves.
  #
  # Every label is marked with N_() at definition and translated with _() on
  # the way out. Marking at definition is what puts the msgid in the
  # catalogue; translating on the way out is what picks up the locale after it
  # is set, rather than at the moment this file is required.
  #
  # This module needs no widget toolkit, which is why it requires only
  # translations.rb: the spec suite loads it on a machine with no display.
  module PdfStrings
    include Translations

    UNKNOWN = N_('Unknown')

    # /Catalog /PageLayout.
    LAYOUTS = {
      'OneColumn'      => N_('Pages in one column'),
      'SinglePage'     => N_('One page at a time'),
      'TwoColumnLeft'  => N_('Odd numbered pages on the left'),
      'TwoColumnRight' => N_('Odd numbered pages on the right'),
      'TwoPageLeft'    => N_('Two odd numbered pages on the left'),
      'TwoPageRight'   => N_('Two odd numbered pages on the right'),
    }.freeze

    NO_LAYOUT = N_('No specific layout')

    # /ViewerPreferences /Duplex.
    DUPLEX = {
      'DuplexFlipLongEdge'  => N_('Flip on the long edge'),
      'DuplexFlipShortEdge' => N_('Flip on the short edge'),
      'Simplex'             => N_('Only single sided'),
    }.freeze

    NO_DUPLEX = N_('No preference')

    # A PDF declares which ISO standard it conforms to in its XMP packet, not
    # in the Info dictionary: each standard owns an XMP namespace prefix, and
    # the presence of that prefix is the declaration. Poppler reads the same
    # packet to fill Document.subtype.
    #
    # The ISO numbers are not marked: upstream does not mark them either
    # (src/Document.vala:440-455), because a standard's number is the same in
    # every language.
    SUBTYPES = {
      'pdfaid'  => 'ISO 19005',
      'pdfeid'  => 'ISO 24517',
      'pdfuaid' => 'ISO 14289',
      'pdfvtid' => 'ISO 16612',
      'pdfxid'  => 'ISO 15930',
    }.freeze

    NOT_COMPLIANT = N_('Not compliant')

    # /ViewerPreferences entries, in the order upstream lists them. Every one
    # is a boolean except /Direction, which is the name R2L when the reading
    # order is right to left.
    VIEWER_PREFERENCES = [
      ['CenterWindow',    true,  N_("Center document's window")],
      ['Direction',       'R2L', N_('Reading order is right to left')],
      ['DisplayDocTitle', true,  N_("Display document's title")],
      ['FitWindow',       true,  N_('Fit document to window')],
      ['HideMenubar',     true,  N_('Hide window menubar')],
      ['HideToolbar',     true,  N_('Hide window toolbars')],
      ['HideWindowUI',    true,  N_('Hide UI elements')],
    ].freeze

    NO_PREFERENCES = N_('No preferences')

    # The bits of /Encrypt /P, paired with the labels upstream gives them.
    # The order is upstream's, which is the order Poppler's flags enumerate
    # in rather than the numeric order of the bits.
    PERMISSIONS = [
      [32,   N_('Adding notes')],
      [1024, N_('Inserting elements')],
      [16,   N_('Copying')],
      [512,  N_('Extracting contents')],
      [256,  N_('Filling interactive forms')],
      [8,    N_('Modifying')],
      [4,    N_('Printing')],
      [2048, N_('Printing in high resolution')],
    ].freeze

    def self.unknown = _(UNKNOWN)

    def self.layout(name) = _(LAYOUTS.fetch(name.to_s, NO_LAYOUT))

    def self.duplex(name) = _(DUPLEX.fetch(name.to_s, NO_DUPLEX))

    # `xmp` is the raw XMP packet; an empty one means no declaration at all,
    # which upstream also reports as not compliant.
    def self.subtype(xmp)
      SUBTYPES.find { |prefix, _ignored| xmp.to_s.include?("#{prefix}:") }
              .then do |match|
                if match
                  match.last
                else
                  _(NOT_COMPLIANT)
                end
              end
    end

    def self.viewer_preferences(dict)
      VIEWER_PREFERENCES.filter_map do |key, expected, label|
        if dict[key] == expected
          _(label)
        end
      end.then do |labels|
        if labels.empty?
          [_(NO_PREFERENCES)]
        else
          labels
        end
      end
    end

    # `flags` is /Encrypt /P, or nil for a document with no security handler,
    # which permits everything. /P is a signed 32-bit integer whose unused
    # high bits are set, so it usually arrives negative; Ruby's integers are
    # two's complement all the way up, so the bit tests work unchanged.
    def self.permissions(flags)
      PERMISSIONS.filter_map do |bit, label|
        if flags.nil? || flags.anybits?(bit)
          _(label)
        end
      end
    end
  end
end
