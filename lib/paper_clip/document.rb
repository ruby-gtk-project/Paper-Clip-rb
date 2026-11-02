# frozen_string_literal: true

require 'adwaita'
require 'zlib'

require_relative 'pdf_strings'
require_relative 'thread_manager'

module PaperClip
  # Document is the PDF whose metadata the editor shows and writes back.
  #
  # Ported from upstream's src/Document.vala. Upstream leans on Poppler for
  # reading and writing the Info dictionary and on Exempi for the XMP packet.
  # Neither library has Ruby bindings available here — there is no Poppler
  # typelib on the system and no exempi binding at all — so this port reads
  # and writes the PDF itself:
  #
  # * reading scans the file for `N G obj … endobj` blocks, inflating
  #   /Type /ObjStm object streams so dictionaries that were compressed are
  #   visible too, and takes the /Info and /Root the newest trailer names.
  #   Later definitions win, which is what an incremental update means;
  # * writing appends an incremental update: the original bytes untouched,
  #   then a fresh Info dictionary, then a cross-reference section of the same
  #   flavour the file already uses chained to the old one through /Prev. A
  #   file this port only partly understands therefore still survives an edit;
  # * the XMP packet is read for the PDF subtype and for has_xmp?, as upstream
  #   does. It is *not* rewritten on save: the editable metadata goes into the
  #   Info dictionary, which is what every reader displays.
  #
  # Encrypted documents raise EncryptedError rather than opening: their
  # strings are ciphertext, and this port carries no crypto layer, so showing
  # them would mean showing mojibake and saving would mean corrupting them.
  class Document
    Error = Class.new(StandardError)
    EncryptedError = Class.new(Error)

    # An indirect reference, `N G R` in the file.
    Reference = Data.define(:number, :generation)

    HEADER = /%PDF-(\d+\.\d+)/
    OBJECT = /(\d+)\s+(\d+)\s+obj\b/
    TRAILER = /\btrailer\b/
    XPACKET = /<\?xpacket begin.*?<\?xpacket end[^>]*\?>/m
    PAGE_OBJECT = %r{/Type\s*/Page(?![A-Za-z])}
    JAVASCRIPT_ACTION = %r{/S\s*/JavaScript}

    # How much of the file after the `trailer` keyword to hand the reader. A
    # trailer dictionary is a few hundred bytes at the very most.
    TRAILER_WINDOW = 4096

    # The Info keys the editor owns, in the order PDF writers conventionally
    # emit them. Only these are written back, so a /Trapped name or a private
    # key in the original is left to the copy that still holds it.
    INFO_ORDER = %w[Title Author Subject Keywords Creator Producer CreationDate ModDate].freeze

    LITERAL_ESCAPES = {
      '\\' => '\\\\',
      '('  => '\\(',
      ')'  => '\\)',
      "\r" => '\\r',
    }.freeze

    PDF_DATE = /\AD?:?(\d{4})(\d{2})?(\d{2})?(\d{2})?(\d{2})?(\d{2})?/

    attr_reader :original_file, :keywords

    # Parsing a large PDF takes long enough to drop frames, so the window
    # opens documents through this rather than calling new directly — the
    # same reason upstream's constructor is async.
    def self.open(file, on_done:, on_error:)
      ThreadManager.run_in_thread(on_done: on_done, on_error: on_error) { new(file) }
    end

    # PDF date strings are `D:YYYYMMDDHHmmSSOHH'mm'`, with everything after
    # the year optional.
    def self.parse_date(raw)
      PDF_DATE.match(raw.to_s).then do |match|
        if match
          Time.new(
            match[1].to_i,
            (match[2] || 1).to_i,
            (match[3] || 1).to_i,
            (match[4] || 0).to_i,
            (match[5] || 0).to_i,
            (match[6] || 0).to_i,
          )
        end
      end
    end

    def self.format_date(time)
      "#{time.strftime('D:%Y%m%d%H%M%S')}#{time.strftime('%z').insert(3, "'")}'"
    end

    def initialize(file)
      @original_file = file
      @observers = []
      @bytes = File.binread(path).freeze
      @objects = {}
      @parsed = {}
      @trailer = {}
      scan_objects
      scan_trailers
      reject_encrypted
      expand_object_streams
      @info = load_info
      @keywords = split_keywords(@info['Keywords'])
    end

    def path = @original_file.path
    def uri = @original_file.uri
    def basename = ::File.basename(path)

    # --- Editable metadata --------------------------------------------------

    def title = @info['Title'].to_s
    def author = @info['Author'].to_s
    def subject = @info['Subject'].to_s
    def creator = @info['Creator'].to_s
    def producer = @info['Producer'].to_s

    def title=(value)
      write_entry('Title', value)
    end

    def author=(value)
      write_entry('Author', value)
    end

    def subject=(value)
      write_entry('Subject', value)
    end

    def creator=(value)
      write_entry('Creator', value)
    end

    def producer=(value)
      write_entry('Producer', value)
    end

    def creation_date = self.class.parse_date(@info['CreationDate'])
    def modification_date = self.class.parse_date(@info['ModDate'])

    def creation_date=(value)
      write_date('CreationDate', value)
    end

    def modification_date=(value)
      write_date('ModDate', value)
    end

    # --- Keywords -----------------------------------------------------------

    def add_keyword(keyword)
      @keywords << keyword.to_s
      notify_change
    end

    # Upstream removes by value; the editor removes by index, because two
    # rows may legitimately hold the same text while they are being typed.
    def remove_keyword(keyword)
      @keywords.index(keyword.to_s).then do |at|
        if at
          remove_keyword_at(at)
        end
      end
    end

    def remove_keyword_at(index)
      @keywords.delete_at(index)
      notify_change
    end

    def update_keyword(index, keyword)
      if @keywords[index] != keyword.to_s
        @keywords[index] = keyword.to_s
        notify_change
      end
    end

    # --- Read-only properties -----------------------------------------------

    def format
      HEADER.match(@bytes[0, 1024].to_s).then do |match|
        if match
          "PDF-#{match[1]}"
        else
          PdfStrings::UNKNOWN
        end
      end
    end

    def layout = PdfStrings.layout(resolve(catalog['PageLayout']))
    def print_duplex = PdfStrings.duplex(resolve(viewer_preferences_dict['Duplex']))
    def viewer_preferences = PdfStrings.viewer_preferences(viewer_preferences_dict)
    def permissions = PdfStrings.permissions(permission_flags)
    def subtype = PdfStrings.subtype(xmp)
    def has_xmp? = !xmp.empty?

    def n_pages
      declared_page_count || counted_page_objects
    end

    # /Names /EmbeddedFiles is the document-level attachment list; a file
    # whose name tree lives in a page annotation only shows up as an
    # /EmbeddedFile stream, so that is the fallback.
    def contains_attachments?
      names_entry('EmbeddedFiles').then do |node|
        node.is_a?(Hash) || @objects.any? { |_, body| body.include?('/EmbeddedFile') }
      end
    end

    def contains_javascript?
      names_entry('JavaScript').then do |node|
        node.is_a?(Hash) || @objects.any? { |_, body| body.match?(JAVASCRIPT_ACTION) }
      end
    end

    # --- Change notification ------------------------------------------------

    # Upstream relies on GObject's notify signal, which DocumentManager hooks
    # to raise its dirty flag. A plain Ruby model needs the hook spelled out.
    def on_change(&block)
      @observers << block
    end

    # --- Saving -------------------------------------------------------------

    def save(target_path)
      ::File.binwrite(target_path, @bytes + update_section)
    end

    def save_async(target_path, on_done: nil, on_error: nil)
      ThreadManager.run_in_thread(on_done: on_done, on_error: on_error) { save(target_path) }
    end

    private

      def notify_change
        @observers.each(&:call)
      end

      def write_entry(key, value)
        if @info[key].to_s != value.to_s
          @info[key] = value.to_s
          notify_change
        end
      end

      def write_date(key, value)
        if value.nil?
          @info.delete(key)
        else
          @info[key] = self.class.format_date(value)
        end
        notify_change
      end

      def split_keywords(raw) = raw.to_s.split(',').map(&:strip).reject(&:empty?)

      # --- Parsing ----------------------------------------------------------

      # Objects are collected in file order and later definitions overwrite
      # earlier ones, so an incrementally updated file resolves to its newest
      # revision without the cross-reference chain having to be walked.
      def scan_objects
        @bytes.to_enum(:scan, OBJECT).each do
          ::Regexp.last_match.then do |match|
            @objects[match[1].to_i] = body_after(match.end(0))
          end
        end
      end

      def body_after(start)
        @bytes.index('endobj', start).then do |finish|
          if finish
            @bytes[start...finish]
          else
            @bytes[start..]
          end
        end
      end

      def scan_trailers
        @trailer = trailer_dicts.reduce({}) { |merged, dict| merged.merge(dict) }
      end

      # Classic files carry a `trailer` keyword; files with cross-reference
      # streams carry the same keys on the stream's own dictionary. Both are
      # collected, newest last, so the merge above leaves the newest in place.
      def trailer_dicts
        [].tap do |dicts|
          @bytes.to_enum(:scan, TRAILER).each do
            ::Regexp.last_match.then do |match|
              dicts << Reader.new(@bytes[match.end(0), TRAILER_WINDOW].to_s).value
            end
          end
          dicts.concat(typed_objects('/XRef', 'XRef'))
        end.grep(Hash)
      end

      # Finds the dictionaries of a given /Type without parsing the whole
      # file: the textual filter first, the reader only on what survives it.
      def typed_objects(needle, type)
        @objects.select { |_, body| body.include?(needle) }
                .keys
                .map { |number| object(number) }
                .select { |dict| dict.is_a?(Hash) && dict['Type'] == type }
      end

      def reject_encrypted
        if @trailer.key?('Encrypt')
          raise EncryptedError, "#{basename} is encrypted"
        end
      end

      # Object streams hold the dictionaries a cross-reference stream file
      # compresses. Their contents only fill gaps: an object also present
      # uncompressed later in the file is the newer one.
      def expand_object_streams
        @objects.select { |_, body| body.include?('/ObjStm') }.each do |number, body|
          object(number).then do |dict|
            if dict.is_a?(Hash) && dict['Type'] == 'ObjStm'
              register_object_stream(body, dict)
            end
          end
        end
      end

      def register_object_stream(body, dict)
        payload = decompress(raw_stream(body, dict).to_s, dict)
        first = resolve(dict['First']).to_i
        pairs = payload[0, first].to_s.scan(/\d+/).map(&:to_i)
        resolve(dict['N']).to_i.times do |index|
          register_sub_object(
            payload,
            first,
            pairs[index * 2],
            pairs[(index * 2) + 1],
          )
        end
      end

      def register_sub_object(payload, first, number, offset)
        if number && offset && !@objects.key?(number)
          @objects[number] = payload[first + offset..].to_s
        end
      end

      def object(number)
        @parsed.fetch(number) { @parsed[number] = parse_object(number) }
      end

      def parse_object(number)
        @objects[number].then do |body|
          if body
            Reader.new(body).value
          end
        end
      end

      def resolve(value)
        if value.is_a?(Reference)
          resolve(object(value.number))
        else
          value
        end
      end

      def raw_stream(body, dict)
        body.index('stream').then do |at|
          if at
            stream_bytes(body, skip_eol(body, at + 6), dict)
          end
        end
      end

      def stream_bytes(body, start, dict)
        resolve(dict['Length']).then do |length|
          if length.is_a?(Integer)
            body[start, length]
          else
            body[start...(body.index('endstream', start) || body.length)]
          end
        end
      end

      def skip_eol(text, at)
        if text[at, 2] == "\r\n"
          at + 2
        elsif "\r\n".include?(text[at].to_s)
          at + 1
        else
          at
        end
      end

      # Only /FlateDecode is handled, which is the only filter object and
      # metadata streams are ever written with in practice.
      def decompress(data, dict)
        filters(dict).reduce(data) do |payload, filter|
          if filter == 'FlateDecode'
            inflate(payload)
          else
            payload
          end
        end
      end

      def filters(dict)
        resolve(dict['Filter']).then do |filter|
          Array(filter)
        end
      end

      def inflate(payload)
        Zlib::Inflate.inflate(payload)
      rescue Zlib::Error
        ''
      end

      # --- Derived dictionaries ---------------------------------------------

      def load_info
        resolve(@trailer['Info']).then do |dict|
          if dict.is_a?(Hash)
            dict.dup
          else
            {}
          end
        end
      end

      def catalog = @catalog ||= find_catalog

      def find_catalog
        resolve(@trailer['Root']).then do |dict|
          if dict.is_a?(Hash)
            dict
          else
            typed_objects('/Catalog', 'Catalog').first || {}
          end
        end
      end

      def viewer_preferences_dict
        resolve(catalog['ViewerPreferences']).then do |dict|
          if dict.is_a?(Hash)
            dict
          else
            {}
          end
        end
      end

      def permission_flags
        resolve(@trailer['Encrypt']).then do |dict|
          if dict.is_a?(Hash)
            resolve(dict['P'])
          end
        end
      end

      # /Pages /Count is authoritative; counting page objects is the fallback
      # for a page tree this port could not follow.
      def declared_page_count
        resolve(catalog['Pages']).then do |pages|
          if pages.is_a?(Hash)
            integer_or_nil(resolve(pages['Count']))
          end
        end
      end

      def integer_or_nil(value)
        if value.is_a?(Integer)
          value
        end
      end

      def counted_page_objects = @objects.count { |_, body| body.match?(PAGE_OBJECT) }

      def names_entry(key)
        resolve(catalog['Names']).then do |names|
          if names.is_a?(Hash)
            resolve(names[key])
          end
        end
      end

      def xmp = @xmp ||= extract_xmp

      # The packet is the catalog's /Metadata stream; failing that, the raw
      # `<?xpacket …?>` envelope anywhere in the file, which is where a writer
      # that never registered the stream leaves it.
      def extract_xmp = metadata_stream || @bytes[XPACKET] || ''

      def metadata_stream
        catalog['Metadata'].then do |reference|
          if reference.is_a?(Reference) && @objects.key?(reference.number)
            metadata_payload(reference.number)
          end
        end
      end

      def metadata_payload(number)
        object(number).then do |dict|
          if dict.is_a?(Hash)
            decompress(raw_stream(@objects[number], dict).to_s, dict)
          end
        end
      end

      # --- Writing ----------------------------------------------------------

      def update_section
        number = @objects.keys.max.to_i + 1
        prefix = "\n".b
        info_offset = @bytes.bytesize + prefix.bytesize
        info = "#{number} 0 obj\n#{serialize_info}\nendobj\n".b
        prefix + info + xref_section(number, info_offset, info_offset + info.bytesize)
      end

      def xref_section(number, info_offset, xref_offset)
        if xref_stream?
          xref_stream(number, info_offset, xref_offset)
        else
          xref_table(number, info_offset, xref_offset)
        end
      end

      # The update has to use the same cross-reference flavour as the section
      # it chains to, so the previous startxref is sniffed for the `xref`
      # keyword a classic table opens with.
      # A file with no readable startxref is treated as classic: a table is
      # the form every reader understands, stream or not.
      def xref_stream?
        if previous_start.zero?
          false
        else
          !@bytes[previous_start, 4].to_s.start_with?('xref')
        end
      end

      def previous_start = @previous_start ||= find_previous_start

      def find_previous_start
        @bytes.rindex('startxref').then do |at|
          if at
            @bytes[at + 9, 64].to_s[/\d+/].to_i
          else
            0
          end
        end
      end

      # Each entry of a classic table is exactly twenty bytes, which is why
      # the `n` is followed by a space before the newline.
      def xref_table(number, info_offset, xref_offset)
        <<~XREF.b
          xref
          #{number} 1
          #{info_offset.to_s.rjust(10, '0')} 00000 n#{' '}
          trailer
          #{trailer_dictionary(number, number + 1)}
          startxref
          #{xref_offset}
          %%EOF
        XREF
      end

      # An /XRef stream holding the two entries this update adds: the new
      # Info dictionary and the stream object itself. /W is [1 4 2] and the
      # payload is left uncompressed, which the format permits.
      def xref_stream(number, info_offset, xref_offset)
        entries = xref_entry(info_offset) + xref_entry(xref_offset)
        "#{number + 1} 0 obj\n#{xref_stream_dictionary(number, entries)}\nstream\n".b +
          entries +
          "\nendstream\nendobj\nstartxref\n#{xref_offset}\n%%EOF\n".b
      end

      def xref_stream_dictionary(number, entries)
        [
          '/Type /XRef',
          "/Size #{number + 2}",
          "/Index [#{number} 2]",
          '/W [1 4 2]',
          root_entry,
          "/Info #{number} 0 R",
          "/Prev #{previous_start}",
          "/Length #{entries.bytesize}",
        ].compact.join(' ').then { |body| "<< #{body} >>" }
      end

      def xref_entry(offset) = [1, offset, 0].pack('CNn')

      def trailer_dictionary(number, size)
        [
          "/Size #{size}",
          root_entry,
          "/Info #{number} 0 R",
          "/Prev #{previous_start}",
        ].compact.join(' ').then { |body| "<< #{body} >>" }
      end

      def root_entry
        @trailer['Root'].then do |reference|
          if reference.is_a?(Reference)
            "/Root #{reference.number} #{reference.generation} R"
          end
        end
      end

      def serialize_info
        INFO_ORDER.filter_map { |key| info_entry(key) }
                  .join("\n")
                  .then { |body| "<<\n#{body}\n>>" }
      end

      def info_entry(key)
        info_value(key).then do |value|
          if value.empty?
            nil
          else
            "/#{key} #{pdf_string(value)}"
          end
        end
      end

      def info_value(key)
        if key == 'Keywords'
          @keywords.reject { |word| word.strip.empty? }.join(',')
        else
          @info[key].to_s
        end
      end

      # A PDF string is either a PDFDocEncoded literal, which agrees with
      # ASCII over the range a literal can safely carry, or UTF-16BE behind a
      # byte-order mark. Anything outside ASCII therefore goes out as the
      # latter.
      def pdf_string(value)
        if value.ascii_only?
          "(#{escape_literal(value)})"
        else
          "<FEFF#{value.encode(Encoding::UTF_16BE).b.unpack1('H*').upcase}>"
        end
      end

      def escape_literal(value)
        value.gsub(/[\\()\r]/) { |char| LITERAL_ESCAPES.fetch(char) }
      end

    # Reader is a recursive-descent reader over the slice of PDF object
    # syntax the Info, Catalog, ViewerPreferences and stream dictionaries
    # use: dictionaries, arrays, names, numbers, references, both kinds of
    # string and the three keyword literals.
    #
    # It is nested inside Document because it is Document's own concern and
    # nothing else has a use for it.
      class Reader
        WHITESPACE = " \t\r\n\f\0"
        DELIMITERS = '()<>[]{}/%'
        REFERENCE = /\G\s+(\d+)\s+R(?![A-Za-z0-9])/
        BOM = "\xFE\xFF"

        ESCAPES = {
          'n'  => "\n",
          'r'  => "\r",
          't'  => "\t",
          'b'  => "\b",
          'f'  => "\f",
          '('  => '(',
          ')'  => ')',
          '\\' => '\\',
        }.freeze

        def initialize(text)
          @text = text
          @pos = 0
        end

        def value
          skip_space
          case @text[@pos]
          when nil then nil
          when '<' then angle
          when '[' then array
          when '/' then name
          when '(' then string
          else token
          end
        end

        private

          def skip_space
            loop do
              char = @text[@pos]
              if char.nil?
                break
              end
              if WHITESPACE.include?(char)
                @pos += 1
                next
              end
              if char == '%'
                @pos = comment_end
                next
              end
              break
            end
          end

          def comment_end
            @text.index("\n", @pos).then do |finish|
              if finish
                finish + 1
              else
                @text.length
              end
            end
          end

          def angle
            if @text[@pos, 2] == '<<'
              dict
            else
              hex_string
            end
          end

          def dict
            @pos += 2
            {}.tap do |hash|
              loop do
                skip_space
                if @text[@pos].nil? || closing_dict?
                  break
                end
                if @text[@pos] == '/'
                  hash[name] = value
                else
                  @pos += 1
                end
              end
            end
          end

          def closing_dict?
            if @text[@pos, 2] == '>>'
              @pos += 2
              true
            else
              false
            end
          end

          def array
            @pos += 1
            [].tap do |list|
              loop do
                skip_space
                if @text[@pos].nil?
                  break
                end
                if @text[@pos] == ']'
                  @pos += 1
                  break
                end
                list << value
              end
            end
          end

          def name
            @pos += 1
            decode_name(regular_run)
          end

          def decode_name(raw)
            raw.gsub(/#([0-9A-Fa-f]{2})/) { ::Regexp.last_match(1).hex.chr }
          end

          # A run of regular characters: everything up to the next whitespace
          # or delimiter.
          def regular_run
            start = @pos
            loop do
              char = @text[@pos]
              if char.nil? || WHITESPACE.include?(char) || DELIMITERS.include?(char)
                break
              end
              @pos += 1
            end
            @text[start...@pos].to_s
          end

          def token
            regular_run.then do |word|
              if word.empty?
                skip_unknown
              else
                atom(word)
              end
            end
          end

          # A delimiter nothing else claimed — a stray `>` or `)`. Stepping
          # over it keeps the loops above from spinning.
          def skip_unknown
            @pos += 1
            nil
          end

          def atom(word)
            case word
            when 'true' then true
            when 'false' then false
            when 'null' then nil
            when /\A[+-]?\d+\z/ then reference_or_integer(word.to_i)
            when /\A[+-]?(?:\d+\.\d*|\.\d+)\z/ then word.to_f
            else word
            end
          end

          def reference_or_integer(number)
            REFERENCE.match(@text, @pos).then do |match|
              if match
                @pos = match.end(0)
                Reference.new(number: number, generation: match[1].to_i)
              else
                number
              end
            end
          end

          def string
            @pos += 1
            decode_text(literal_body)
          end

          def literal_body
            depth = 1
            out = +''
            loop do
              char = @text[@pos]
              if char.nil?
                break
              end
              @pos += 1
              if char == '\\'
                out << escape
                next
              end
              depth += delta(char)
              if depth.zero?
                break
              end
              out << char
            end
            out
          end

          def delta(char)
            case char
            when '(' then 1
            when ')' then -1
            else 0
            end
          end

          def escape
            char = @text[@pos]
            @pos += 1
            if char.to_s.match?(/[0-7]/)
              octal(char)
            elsif char == "\n"
              ''
            else
              ESCAPES.fetch(char, char.to_s)
            end
          end

          def octal(first)
            digits = +first
            2.times do
              if @text[@pos].to_s.match?(/[0-7]/)
                digits << @text[@pos]
                @pos += 1
              end
            end
            digits.to_i(8).chr
          end

          def hex_string
            @pos += 1
            finish = @text.index('>', @pos) || @text.length
            digits = @text[@pos...finish].to_s.gsub(/[^0-9A-Fa-f]/, '')
            @pos = finish + 1
            decode_text(pad(digits).scan(/../).map { |pair| pair.hex.chr }.join)
          end

          def pad(digits)
            if digits.length.odd?
              "#{digits}0"
            else
              digits
            end
          end

          # PDF text strings are UTF-16BE behind a byte-order mark, or
          # PDFDocEncoded, which agrees with Latin-1 over the range metadata
          # uses.
          def decode_text(raw)
            raw.dup.force_encoding(Encoding::BINARY).then do |bytes|
              if bytes.start_with?(BOM.b)
                transcode(bytes.byteslice(2..).to_s, Encoding::UTF_16BE)
              else
                transcode(bytes, Encoding::ISO_8859_1)
              end
            end
          end

          def transcode(bytes, from)
            bytes.force_encoding(from).encode(
              Encoding::UTF_8,
              invalid: :replace,
              undef:   :replace,
            )
          end
      end
  end
end
