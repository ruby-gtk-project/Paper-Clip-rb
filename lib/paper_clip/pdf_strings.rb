# frozen_string_literal: true

require 'adwaita'

module PaperClip
  # PdfStrings turns the enumerations and bit flags a PDF carries into the
  # human-readable strings the details list shows.
  #
  # Ported from the string tables in upstream's src/Document.vala —
  # layout_to_string, print_duplex_to_string, subtype_to_string,
  # viewer_preferences_to_string_array and permissions_to_string_array.
  # Upstream switches on Poppler enum members; this port reads the PDF
  # dictionaries directly, so the keys here are the PDF names themselves.
  module PdfStrings
    UNKNOWN = 'Unknown'

    # /Catalog /PageLayout.
    LAYOUTS = {
      'OneColumn'      => 'Pages in one column',
      'SinglePage'     => 'One page at a time',
      'TwoColumnLeft'  => 'Odd numbered pages on the left',
      'TwoColumnRight' => 'Odd numbered pages on the right',
      'TwoPageLeft'    => 'Two odd numbered pages on the left',
      'TwoPageRight'   => 'Two odd numbered pages on the right',
    }.freeze

    NO_LAYOUT = 'No specific layout'

    # /ViewerPreferences /Duplex.
    DUPLEX = {
      'DuplexFlipLongEdge'  => 'Flip on the long edge',
      'DuplexFlipShortEdge' => 'Flip on the short edge',
      'Simplex'             => 'Only single sided',
    }.freeze

    NO_DUPLEX = 'No preference'

    # A PDF declares which ISO standard it conforms to in its XMP packet, not
    # in the Info dictionary: each standard owns an XMP namespace prefix, and
    # the presence of that prefix is the declaration. Poppler reads the same
    # packet to fill Document.subtype.
    SUBTYPES = {
      'pdfaid'  => 'ISO 19005',
      'pdfeid'  => 'ISO 24517',
      'pdfuaid' => 'ISO 14289',
      'pdfvtid' => 'ISO 16612',
      'pdfxid'  => 'ISO 15930',
    }.freeze

    NOT_COMPLIANT = 'Not compliant'

    # /ViewerPreferences entries, in the order upstream lists them. Every one
    # is a boolean except /Direction, which is the name R2L when the reading
    # order is right to left.
    VIEWER_PREFERENCES = [
      ['CenterWindow',    true,  "Center document's window"],
      ['Direction',       'R2L', 'Reading order is right to left'],
      ['DisplayDocTitle', true,  "Display document's title"],
      ['FitWindow',       true,  'Fit document to window'],
      ['HideMenubar',     true,  'Hide window menubar'],
      ['HideToolbar',     true,  'Hide window toolbars'],
      ['HideWindowUI',    true,  'Hide UI elements'],
    ].freeze

    NO_PREFERENCES = 'No preferences'

    # The bits of /Encrypt /P, paired with the labels upstream gives them.
    # The order is upstream's, which is the order Poppler's flags enumerate
    # in rather than the numeric order of the bits.
    PERMISSIONS = [
      [32,   'Adding notes'],
      [1024, 'Inserting elements'],
      [16,   'Copying'],
      [512,  'Extracting contents'],
      [256,  'Filling interactive forms'],
      [8,    'Modifying'],
      [4,    'Printing'],
      [2048, 'Printing in high resolution'],
    ].freeze

    def self.layout(name) = LAYOUTS.fetch(name.to_s, NO_LAYOUT)

    def self.duplex(name) = DUPLEX.fetch(name.to_s, NO_DUPLEX)

    # `xmp` is the raw XMP packet; an empty one means no declaration at all,
    # which upstream also reports as not compliant.
    def self.subtype(xmp)
      SUBTYPES.find { |prefix, _| xmp.to_s.include?("#{prefix}:") }
              .then do |match|
                if match
                  match.last
                else
                  NOT_COMPLIANT
                end
              end
    end

    def self.viewer_preferences(dict)
      VIEWER_PREFERENCES.filter_map do |key, expected, label|
        if dict[key] == expected
          label
        end
      end.then do |labels|
        if labels.empty?
          [NO_PREFERENCES]
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
          label
        end
      end
    end
  end
end
