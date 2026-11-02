# frozen_string_literal: true

require 'gio2'
require 'fileutils'
require 'tmpdir'
require 'zlib'

require_relative 'pdf_crypt'
require_relative 'pdf_strings'
require_relative 'poppler'
require_relative 'thread_manager'
require_relative 'xmp_packet'

module PaperClip
  # Document is the PDF whose metadata the editor shows and writes back.
  #
  # Ported from upstream's src/Document.vala. Upstream leans on Poppler for
  # reading and writing the Info dictionary and on Exempi for the XMP packet.
  #
  # Poppler is available to this port — `lib/paper_clip/poppler.rb` loads its
  # introspection typelib — but it is used for rendering only, by
  # get_page_for_index and the thumbnail behind it. Metadata is not read
  # through it, deliberately: this parser accepts files Poppler refuses, and
  # handing the reader over would narrow the set of documents the editor
  # opens at all. libexempi has no Ruby binding, so the XMP packet is edited
  # as the XML it is — see XmpPacket — rather than left unwritten.
  #
  # So this port reads and writes the PDF itself:
  #
  # * reading copies the original into `$TMPDIR/copies` first, exactly as
  #   upstream's create_copy_from_original does (src/Document.vala:467-495),
  #   and parses and mutates that copy. A save writes the copy out to the
  #   chosen path, so a failed or interrupted write damages a temporary file
  #   and never the only copy the user has;
  # * the scan finds `N G obj … endobj` blocks, inflating /Type /ObjStm
  #   object streams so dictionaries that were compressed are visible too,
  #   and takes the /Info and /Root the newest trailer names. Later
  #   definitions win, which is what an incremental update means;
  # * writing appends an incremental update: the cached bytes untouched, then
  #   a fresh Info dictionary, then a rewritten /Metadata stream when the file
  #   has one, then a cross-reference section of the same flavour the file
  #   already uses chained to the old one through /Prev. A file this port only
  #   partly understands therefore still survives an edit;
  # * an encrypted document opens: PdfCrypt derives the file key from the
  #   password, strings in the Info dictionary are decrypted on the way in and
  #   re-encrypted on the way out, and a file whose password is not yet known
  #   raises EncryptedError so the window can raise the PasswordDialog;
  # * the XMP packet is mirrored on save whenever the file has one, which is
  #   what upstream's save_xmp does (src/Document.vala:227-270): Producer,
  #   CreatorTool, Keywords, dc:title, CreateDate, ModifyDate and a fresh
  #   MetadataDate, with the two dates deleted rather than blanked when the
  #   row is empty.
  class Document
    Error = Class.new(StandardError)
    EncryptedError = Class.new(Error)

    # A PDF text string, decoded for display with its original bytes kept:
    # /O, /U and anything the security handler touches is key material, and
    # only the bytes will do.
    class PdfText < String
      attr_reader :raw

      def initialize(text, raw)
        super(text)
        @raw = raw
      end
    end

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

    # Where the copy of the original goes. Upstream builds the same path with
    # Path.build_path (src/Document.vala:471-473).
    COPIES_DIRECTORY = 'copies'

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

    attr_reader :original_file, :cached_path, :keywords

    # Parsing a large PDF takes long enough to drop frames, so the window
    # opens documents through this rather than calling new directly — the
    # same reason upstream's constructor is async.
    def self.open(file, on_done:, on_error:, password: nil)
      ThreadManager.run_in_thread(on_done: on_done, on_error: on_error) { new(file, password) }
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

    def initialize(file, password = nil)
      @original_file = file
      @password = password
      @observers = []
      @keyword_observers = []
      @cached_path = create_copy_from_original
      @bytes = ::File.binread(@cached_path).freeze
      @objects = {}
      @generations = {}
      @parsed = {}
      @trailer = {}
      scan_objects
      scan_trailers
      unlock_or_refuse
      expand_object_streams
      @info = load_info
      @keywords = split_keywords(@info['Keywords'])
    end

    def path = @original_file.path
    def uri = @original_file.uri
    def basename = ::File.basename(path)

    # The copy in $TMPDIR/copies, which is the file this object actually
    # parsed and the one a save writes out. Upstream exposes the same thing
    # as Document.cached_file (src/Document.vala:464).
    def cached_file = @cached_file ||= Gio::File.new_for_path(@cached_path)

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
      notify_keywords(@keywords.length - 1, 0, 1)
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
      notify_keywords(index, 1, 0)
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
          PdfStrings.unknown
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

    # The page the thumbnail renders. Upstream forwards straight to the
    # Poppler document it opened in its constructor
    # (src/Document.vala:290-292); here the Poppler document is a second,
    # independent read of the same bytes, so this answers nil rather than
    # raising when Poppler will not have the file.
    def get_page_for_index(index)
      poppler_document.then do |document|
        if document && index < document.n_pages
          document.get_page(index)
        end
      end
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

    # The counterpart of items-changed on upstream's keyword ListStore, which
    # KeywordList connects to (src/KeywordList.vala:38). It carries the same
    # three arguments, and like items-changed it fires only when the number of
    # keywords changes — editing the text of one is a change to the document
    # and not to the list, so a row being typed into is never rebuilt.
    def on_keywords_changed(&block)
      @keyword_observers << block
    end

    # --- Saving -------------------------------------------------------------

    # Upstream's save_thread writes the cached copy out to the chosen URI and
    # then mirrors the XMP packet into it (src/Document.vala:217-225). Here
    # both happen in one write: the cached bytes, the new Info dictionary, the
    # rewritten /Metadata stream when there is one, and the cross-reference
    # section that points at them.
    def save(target_path)
      ::File.binwrite(target_path, @bytes + update_section)
    end

    def save_async(target_path, on_done: nil, on_error: nil)
      ThreadManager.run_in_thread(on_done: on_done, on_error: on_error) { save(target_path) }
    end

    private

      # --- The cached copy ---------------------------------------------------

      # Upstream shells out to `cp` through a SubprocessLauncher
      # (src/Document.vala:482); FileUtils.cp is the same copy without the
      # fork. The basename is upstream's too, so reopening the same document
      # overwrites its own copy rather than filling $TMPDIR.
      def create_copy_from_original
        copies_directory.then do |directory|
          ::File.join(directory, ::File.basename(@original_file.path)).tap do |destination|
            FileUtils.cp(@original_file.path, destination)
          end
        end
      end

      def copies_directory
        ::File.join(Dir.tmpdir, COPIES_DIRECTORY).tap do |directory|
          FileUtils.mkdir_p(directory, mode: 0o700)
        end
      end

      # --- Rendering ---------------------------------------------------------

      # Poppler's own read of the file, used for nothing but rasterising a
      # page. It is opened lazily rather than in the constructor, where
      # upstream opens its one and only Poppler document: this port parses
      # the file itself and accepts files Poppler rejects, and opening
      # Poppler eagerly would hand that rejection to the user as a document
      # that will not open at all rather than as a preview that is missing.
      #
      # `defined?` and not `||=`, so a file Poppler has already refused is
      # refused once instead of being re-parsed for every thumbnail.
      def poppler_document
        unless defined?(@poppler_document)
          @poppler_document = open_with_poppler
        end
        @poppler_document
      end

      # The cached copy and not the original: it is byte-identical, and it is
      # the file every other read in this class goes through.
      #
      # Poppler::Error and not GLib::Error: the error domain's classes
      # descend from GLib::ErrorInfo, not from GLib::Error, so a
      # `rescue GLib::Error` here would let Poppler::Error::Damaged straight
      # through. GLib::Error is kept beside it for the failures that come
      # from Gio rather than from Poppler.
      def open_with_poppler
        Poppler.open(cached_file.uri, @password)
      rescue Poppler::Error, GLib::Error => e
        warn("Poppler could not open #{basename}: #{e.message}")
        nil
      end

      # --- Encryption --------------------------------------------------------

      # Poppler tries the empty password before it reports a file as
      # encrypted, which is why a document with an owner password but no user
      # password opens with no dialog at all. A file that needs a password the
      # caller does not have raises, and the window turns that into the
      # PasswordDialog or — when it had already supplied one — into upstream's
      # "the provided password is incorrect" toast.
      def unlock_or_refuse
        if @trailer.key?('Encrypt')
          @crypt = PdfCrypt.open(resolve(@trailer['Encrypt']), file_id, @password)
          if @crypt.nil?
            raise EncryptedError, "#{basename} is encrypted"
          end
        end
      end

      # The first element of the trailer's /ID array, which is key material
      # and so is taken as bytes rather than as the decoded text.
      def file_id
        Array(@trailer['ID']).first.then do |value|
          if value.respond_to?(:raw)
            value.raw
          else
            value.to_s.b
          end
        end
      end

      # Walks a parsed value and replaces every string with its plaintext.
      # The Info dictionary is the only thing this port decrypts, because it
      # is the only thing it shows.
      def decrypt_strings(value, number, generation)
        case value
        when PdfText then decrypted_text(value, number, generation)
        when Hash then value.transform_values { |item| decrypt_strings(item, number, generation) }
        when Array then value.map { |item| decrypt_strings(item, number, generation) }
        else value
        end
      end

      def decrypted_text(value, number, generation)
        @crypt.decrypt_string(value.raw, number, generation)
               .then { |plain| Reader.decode_text(plain) }
      end

      def notify_change
        @observers.each(&:call)
      end

      def notify_keywords(position, removed, added)
        @keyword_observers.each { |observer| observer.call(position, removed, added) }
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
            @generations[match[1].to_i] = match[2].to_i
          end
        end
      end

      def generation_of(number) = @generations.fetch(number, 0)

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
              register_object_stream(body, dict, number)
            end
          end
        end
      end

      def register_object_stream(body, dict, number)
        payload = decompress(decrypt_stream(raw_stream(body, dict).to_s, number), dict)
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

      # A stream in an encrypted file is ciphertext before it is Flate, and
      # the key depends on the object it lives in.
      def decrypt_stream(data, number)
        if @crypt
          @crypt.decrypt_stream(data, number, generation_of(number))
        else
          data
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
            decrypted_info(dict.dup)
          else
            {}
          end
        end
      end

      def decrypted_info(dict)
        if @crypt
          info_reference.then do |reference|
            decrypt_strings(dict, reference.number, reference.generation)
          end
        else
          dict
        end
      end

      def info_reference
        @trailer['Info'].then do |reference|
          if reference.is_a?(Reference)
            reference
          else
            Reference.new(number: 0, generation: 0)
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

      # The object number of the /Metadata stream, or nil when the catalog
      # does not register one. A save can only rewrite a packet it can name,
      # so this is also what decides whether the XMP is mirrored.
      def metadata_number
        catalog['Metadata'].then do |reference|
          if reference.is_a?(Reference) && @objects.key?(reference.number)
            reference.number
          end
        end
      end

      def metadata_stream
        metadata_number.then do |number|
          if number
            metadata_payload(number)
          end
        end
      end

      # /EncryptMetadata false leaves the packet in the clear so an indexer
      # can read it without the password, and the handler must then be
      # skipped rather than applied to plaintext.
      def metadata_payload(number)
        object(number).then do |dict|
          if dict.is_a?(Hash)
            decompress(metadata_bytes(raw_stream(@objects[number], dict).to_s, number), dict)
          end
        end
      end

      def metadata_bytes(data, number)
        if @crypt&.encrypt_metadata?
          @crypt.decrypt_stream(data, number, generation_of(number))
        else
          data
        end
      end

      # --- Writing ----------------------------------------------------------

      # The update carries one object always — the new Info dictionary — and
      # a second when the file has an XMP packet to mirror, which is a fresh
      # revision of the /Metadata stream under its existing object number.
      def update_section
        prefix = "\n".b
        laid_out = lay_out(updated_objects, @bytes.bytesize + prefix.bytesize)
        prefix +
          laid_out.map { |entry| entry.fetch(:bytes) }.join.b +
          xref_section(laid_out, laid_out.sum { |entry| entry.fetch(:bytes).bytesize } + @bytes.bytesize + prefix.bytesize)
      end

      def updated_objects
        [info_object].tap do |objects|
          metadata_object.then do |entry|
            if entry
              objects << entry
            end
          end
        end.sort_by { |entry| entry.fetch(:number) }
      end

      def info_object
        new_object_number.then do |number|
          {
            number: number,
            body:   "#{number} 0 obj\n#{serialize_info(number)}\nendobj\n",
          }
        end
      end

      def new_object_number = @new_object_number ||= @objects.keys.max.to_i + 1

      # Upstream writes the packet only when has_xmp is true
      # (src/Document.vala:222); a file with no registered /Metadata stream
      # has nothing to rewrite, and inventing one would mean inventing a
      # catalog revision too.
      def metadata_object
        metadata_number.then do |number|
          if number && has_xmp?
            {
              number: number,
              body:   metadata_object_body(number),
            }
          end
        end
      end

      def metadata_object_body(number)
        mirrored_xmp.then do |packet|
          encrypted_metadata(packet, number).then do |payload|
            "#{number} #{generation_of(number)} obj\n" \
              "<< /Type /Metadata /Subtype /XML /Length #{payload.bytesize} >>\n" \
              "stream\n#{payload}\nendstream\nendobj\n"
          end
        end
      end

      # The /Metadata stream goes out uncompressed, which the format permits
      # and which an XMP-aware reader prefers: the packet is meant to be
      # findable by scanning the bytes.
      def encrypted_metadata(packet, number)
        if @crypt&.encrypt_metadata?
          @crypt.encrypt_stream(packet.b, number, generation_of(number))
        else
          packet.b
        end
      end

      def mirrored_xmp
        XmpPacket.new(xmp).mirror(
          producer:          producer,
          creator:           creator,
          keywords:          info_value('Keywords'),
          title:             title,
          creation_date:     creation_date,
          modification_date: modification_date,
        )
      end

      # Gives each object its offset in the file being written, which is what
      # the cross-reference section records.
      def lay_out(objects, start)
        offset = start
        objects.map do |entry|
          entry.fetch(:body).b.then do |bytes|
            { number: entry.fetch(:number), bytes: bytes, offset: offset }.tap { offset += bytes.bytesize }
          end
        end
      end

      def xref_section(entries, xref_offset)
        if xref_stream?
          xref_stream(entries, xref_offset)
        else
          xref_table(entries, xref_offset)
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
      # the `n` is followed by a space before the newline. One subsection per
      # object, because the two objects an update writes are not adjacent.
      def xref_table(entries, xref_offset)
        <<~XREF.b
          xref
          #{entries.map { |entry| table_subsection(entry) }.join}trailer
          #{trailer_dictionary}
          startxref
          #{xref_offset}
          %%EOF
        XREF
      end

      def table_subsection(entry)
        "#{entry.fetch(:number)} 1\n" \
          "#{entry.fetch(:offset).to_s.rjust(10, '0')} #{generation_field(entry)} n \n"
      end

      def generation_field(entry)
        generation_of(entry.fetch(:number)).to_s.rjust(5, '0')
      end

      # An /XRef stream holding the entries this update adds plus the stream
      # object itself. /W is [1 4 2] and the payload is left uncompressed,
      # which the format permits.
      def xref_stream(entries, xref_offset)
        stream_number = new_object_number + 1
        payload = xref_payload(entries, stream_number, xref_offset)
        "#{stream_number} 0 obj\n#{xref_stream_dictionary(entries, stream_number, payload)}\nstream\n".b +
          payload +
          "\nendstream\nendobj\nstartxref\n#{xref_offset}\n%%EOF\n".b
      end

      def xref_payload(entries, stream_number, xref_offset)
        xref_rows(entries, stream_number, xref_offset)
          .map { |number, offset| xref_entry(offset, generation_of(number)) }
          .join
          .b
      end

      def xref_rows(entries, stream_number, xref_offset)
        entries.map { |entry| [entry.fetch(:number), entry.fetch(:offset)] }
               .push([stream_number, xref_offset])
               .sort_by(&:first)
      end

      def xref_stream_dictionary(entries, stream_number, payload)
        [
          '/Type /XRef',
          "/Size #{stream_number + 1}",
          "/Index [#{xref_index(entries, stream_number)}]",
          '/W [1 4 2]',
          root_entry,
          "/Info #{new_object_number} 0 R",
          "/Prev #{previous_start}",
          "/Length #{payload.bytesize}",
        ].compact.join(' ').then { |body| "<< #{body} >>" }
      end

      def xref_index(entries, stream_number)
        xref_rows(entries, stream_number, 0).map { |number, _offset| "#{number} 1" }.join(' ')
      end

      def xref_entry(offset, generation) = [1, offset, generation].pack('CNn')

      def trailer_dictionary
        [
          "/Size #{new_object_number + 1}",
          root_entry,
          "/Info #{new_object_number} 0 R",
          encrypt_entry,
          id_entry,
          "/Prev #{previous_start}",
        ].compact.join(' ').then { |body| "<< #{body} >>" }
      end

      # An encrypted file's trailer has to keep naming its security handler
      # and its /ID, or a reader that follows the new /Prev chain finds a
      # trailer that says the document is in the clear.
      def encrypt_entry
        @trailer['Encrypt'].then do |reference|
          if reference.is_a?(Reference)
            "/Encrypt #{reference.number} #{reference.generation} R"
          end
        end
      end

      def id_entry
        if @crypt
          Array(@trailer['ID']).map { |value| hex_string(value) }
                               .then { |values| "/ID [#{values.join(' ')}]" }
        end
      end

      def hex_string(value)
        if value.respond_to?(:raw)
          "<#{value.raw.unpack1('H*')}>"
        else
          "<#{value.to_s.b.unpack1('H*')}>"
        end
      end

      def root_entry
        @trailer['Root'].then do |reference|
          if reference.is_a?(Reference)
            "/Root #{reference.number} #{reference.generation} R"
          end
        end
      end

      def serialize_info(number)
        INFO_ORDER.filter_map { |key| info_entry(key, number) }
                  .join("\n")
                  .then { |body| "<<\n#{body}\n>>" }
      end

      def info_entry(key, number)
        info_value(key).then do |value|
          if value.empty?
            nil
          else
            "/#{key} #{pdf_string(value, number)}"
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
      #
      # In an encrypted file the bytes are ciphertext, and ciphertext has no
      # safe literal form, so it always goes out as hex.
      def pdf_string(value, number)
        if @crypt
          encrypted_string(value, number)
        elsif value.ascii_only?
          "(#{escape_literal(value)})"
        else
          "<FEFF#{value.encode(Encoding::UTF_16BE).b.unpack1('H*').upcase}>"
        end
      end

      def encrypted_string(value, number)
        @crypt.encrypt_string(plain_bytes(value), number, 0)
              .then { |cipher| "<#{cipher.unpack1('H*').upcase}>" }
      end

      def plain_bytes(value)
        if value.ascii_only?
          value.b
        else
          Reader::BOM.b + value.encode(Encoding::UTF_16BE).b
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

        # PDF text strings are UTF-16BE behind a byte-order mark, or
        # PDFDocEncoded, which agrees with Latin-1 over the range metadata
        # uses. The original bytes travel with the result, because the
        # security handler needs them and because re-encoding a decoded
        # string is not always the identity.
        def self.decode_text(raw)
          raw.dup.force_encoding(Encoding::BINARY).then do |bytes|
            if bytes.start_with?(BOM.b)
              PdfText.new(transcode(bytes.byteslice(2..).to_s, Encoding::UTF_16BE), bytes)
            else
              PdfText.new(transcode(bytes, Encoding::ISO_8859_1), bytes)
            end
          end
        end

        def self.transcode(bytes, from)
          bytes.dup.force_encoding(from).encode(
            Encoding::UTF_8,
            invalid: :replace,
            undef:   :replace,
          )
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

          def decode_text(raw) = self.class.decode_text(raw)
      end
  end
end
