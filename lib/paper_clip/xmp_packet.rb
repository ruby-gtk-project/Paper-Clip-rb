# frozen_string_literal: true

module PaperClip
  # XmpPacket reads and rewrites the XMP metadata packet of a PDF.
  #
  # Ported from the Exempi calls in upstream's src/Document.vala:227-270,
  # which mirror the Info dictionary into the packet on every save of a file
  # that has one. Upstream reaches libexempi through a VAPI; this port has no
  # exempi binding, so the packet is edited as the XML it is.
  #
  # That is sound because the only properties either program writes are the
  # seven simple ones below. Nothing here reflows the RDF, renames a prefix or
  # touches a property it was not asked about: an unknown schema in the packet
  # comes out of a save byte-identical.
  #
  # A property can be carried two ways in RDF — as a child element or as an
  # attribute on rdf:Description — and a packet written by one tool and edited
  # by another often holds both forms at once. Both are handled, and a write
  # updates whichever form is already there rather than adding a second.
  class XmpPacket
    # The namespaces upstream names through Xmp.Namespace, with the prefix
    # files conventionally bind them to.
    NAMESPACES = {
      'pdf' => 'http://ns.adobe.com/pdf/1.3/',
      'xmp' => 'http://ns.adobe.com/xap/1.0/',
      'dc'  => 'http://purl.org/dc/elements/1.1/',
    }.freeze

    # Upstream's Xmp.Namespace.XAP is the schema whose conventional prefix is
    # `xmp:`; a packet written before 2004 may still bind it as `xap:`, so
    # both spellings are looked for when reading and the one already present
    # is the one written back.
    XAP_PREFIXES = %w[xmp xap].freeze

    DESCRIPTION_OPEN = /<rdf:Description\b[^>]*?(\/?)>/m
    RDF_OPEN = /<rdf:RDF\b[^>]*>/m
    XPACKET_END = /<\?xpacket\s+end\s*=\s*(['"])([^'"]*)\1\s*\?>/

    attr_reader :text

    def initialize(text)
      @text = text.to_s.dup
    end

    def empty? = @text.strip.empty?

    # The seven properties upstream mirrors. `creation_date` and
    # `modification_date` are deleted rather than blanked when nil, which is
    # what Xmp.Meta.delete_property does at src/Document.vala:252 and :258;
    # MetadataDate is stamped on every save, as src/Document.vala:263 does.
    def mirror(producer:, creator:, keywords:, title:, creation_date:, modification_date:, metadata_date: Time.now)
      set('pdf', 'Producer', producer)
      set(xap_prefix, 'CreatorTool', creator)
      set('pdf', 'Keywords', keywords)
      set_language_alternative('dc', 'title', title)
      write_or_delete(xap_prefix, 'CreateDate', creation_date)
      write_or_delete(xap_prefix, 'ModifyDate', modification_date)
      set(xap_prefix, 'MetadataDate', self.class.format_date(metadata_date))
      @text
    end

    def get(prefix, property)
      element_value(prefix, property) || attribute_value(prefix, property)
    end

    # The prefix the packet already binds to the XAP schema, defaulting to the
    # modern spelling for a packet that does not mention it.
    def xap_prefix
      @xap_prefix ||= XAP_PREFIXES.find { |prefix| @text.include?("xmlns:#{prefix}=") } || 'xmp'
    end

    def self.format_date(time)
      time.strftime('%Y-%m-%dT%H:%M:%S%:z')
    end

    def set(prefix, property, value)
      if element_value(prefix, property)
        replace_element(prefix, property, value)
      elsif attribute_value(prefix, property)
        replace_attribute(prefix, property, value)
      else
        insert_element(prefix, property, value)
      end
    end

    # dc:title is a language alternative, not a simple property: upstream
    # writes it with set_localized_text under x-default
    # (src/Document.vala:249).
    def set_language_alternative(prefix, property, value)
      alternative_body(value).then do |body|
        if element_value(prefix, property)
          @text.sub!(element_pattern(prefix, property)) { "<#{prefix}:#{property}>#{body}</#{prefix}:#{property}>" }
        else
          delete_attribute(prefix, property)
          insert_raw(prefix, property, body)
        end
      end
    end

    def delete(prefix, property)
      @text.sub!(element_pattern(prefix, property), '')
      delete_attribute(prefix, property)
    end

    private

      def write_or_delete(prefix, property, time)
        if time.nil?
          delete(prefix, property)
        else
          set(prefix, property, self.class.format_date(time))
        end
      end

      def alternative_body(value)
        "<rdf:Alt><rdf:li xml:lang=\"x-default\">#{escape(value)}</rdf:li></rdf:Alt>"
      end

      def element_pattern(prefix, property)
        %r{<#{prefix}:#{property}\b[^>]*?(?:/>|>.*?</#{prefix}:#{property}>)}m
      end

      def attribute_pattern(prefix, property)
        /\s#{prefix}:#{property}\s*=\s*(['"])(.*?)\1/m
      end

      def element_value(prefix, property)
        @text[%r{<#{prefix}:#{property}\b[^>]*>(.*?)</#{prefix}:#{property}>}m, 1]
      end

      def attribute_value(prefix, property)
        @text[attribute_pattern(prefix, property), 2]
      end

      def replace_element(prefix, property, value)
        @text.sub!(element_pattern(prefix, property)) do
          "<#{prefix}:#{property}>#{escape(value)}</#{prefix}:#{property}>"
        end
      end

      def replace_attribute(prefix, property, value)
        @text.sub!(attribute_pattern(prefix, property)) { " #{prefix}:#{property}=\"#{escape(value)}\"" }
      end

      def delete_attribute(prefix, property)
        @text.sub!(attribute_pattern(prefix, property), '')
      end

      def insert_element(prefix, property, value)
        insert_raw(prefix, property, escape(value))
      end

      # A property whose schema no rdf:Description declares needs a
      # Description of its own, which is legal RDF and what Exempi emits too.
      def insert_raw(prefix, property, body)
        "<#{prefix}:#{property}>#{body}</#{prefix}:#{property}>".then do |element|
          if description_for?(prefix)
            insert_into_description(prefix, element)
          else
            insert_new_description(prefix, element)
          end
        end
      end

      def description_for?(prefix)
        @text.match?(/<rdf:Description\b[^>]*xmlns:#{prefix}=/m)
      end

      def insert_into_description(prefix, element)
        @text.sub!(/(<rdf:Description\b[^>]*xmlns:#{prefix}=[^>]*?)(\/?)>/m) do
          open = ::Regexp.last_match(1)
          if ::Regexp.last_match(2).empty?
            "#{open}>#{element}"
          else
            "#{open}>#{element}</rdf:Description>"
          end
        end
      end

      def insert_new_description(prefix, element)
        "<rdf:Description rdf:about=\"\" xmlns:#{prefix}=\"#{NAMESPACES.fetch(prefix, schema_for(prefix))}\">" \
          "#{element}</rdf:Description>".then do |description|
            @text.sub!(RDF_OPEN) { "#{::Regexp.last_match(0)}#{description}" }
          end
      end

      # The XAP schema under either prefix, and otherwise whatever the packet
      # already binds, so a nonstandard prefix is not given a wrong URI.
      def schema_for(prefix)
        if XAP_PREFIXES.include?(prefix)
          NAMESPACES.fetch('xmp')
        else
          @text[/xmlns:#{prefix}=(['"])(.*?)\1/m, 2].to_s
        end
      end

      def escape(value)
        value.to_s
             .gsub('&', '&amp;')
             .gsub('<', '&lt;')
             .gsub('>', '&gt;')
             .gsub('"', '&quot;')
      end
  end
end
