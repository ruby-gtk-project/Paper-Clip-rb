# frozen_string_literal: true

require "time"
require "tmpdir"

require_relative "../support/pdf_fixtures"

RSpec.describe PaperClip::XmpPacket do
  def packet(text = PdfFixtures::XMP_PACKET) = described_class.new(text)

  def mirrored(overrides = {})
    packet.mirror(
      **{
        producer:          "Paper Clip",
        creator:           "Paper Clip Ruby",
        keywords:          "alpha,beta",
        title:             "New Title",
        creation_date:     Time.parse("2024-01-15T10:30:00+00:00"),
        modification_date: Time.parse("2024-02-01T09:00:00+00:00"),
        metadata_date:     Time.parse("2026-03-04T05:06:07+00:00"),
      }.merge(overrides),
    )
  end

  it "updates a property carried as an attribute, in place" do
    expect(mirrored).to include('pdf:Producer="Paper Clip"')
    expect(mirrored).not_to include("Old Producer")
  end

  it "updates a property carried as an element, in place" do
    expect(mirrored).to include("<xmp:CreatorTool>Paper Clip Ruby</xmp:CreatorTool>")
    expect(mirrored).not_to include("Old Tool")
  end

  it "writes dc:title as a language alternative under x-default" do
    expect(mirrored).to include('<rdf:li xml:lang="x-default">New Title</rdf:li>')
    expect(mirrored).not_to include("Old XMP Title")
  end

  it "adds a property the packet did not carry" do
    expect(mirrored).to include("<pdf:Keywords>alpha,beta</pdf:Keywords>")
  end

  it "stamps MetadataDate on every mirror" do
    expect(mirrored).to include("<xmp:MetadataDate>2026-03-04T05:06:07+00:00</xmp:MetadataDate>")
  end

  it "writes the dates in ISO 8601 with an offset" do
    expect(mirrored).to include("<xmp:CreateDate>2024-01-15T10:30:00+00:00</xmp:CreateDate>")
    expect(mirrored).to include("<xmp:ModifyDate>2024-02-01T09:00:00+00:00</xmp:ModifyDate>")
  end

  it "deletes CreateDate rather than blanking it when the row is empty" do
    result = mirrored(creation_date: nil)

    expect(result).not_to include("xmp:CreateDate")
    expect(result).to include("xmp:ModifyDate")
  end

  it "deletes ModifyDate rather than blanking it when the row is empty" do
    result = mirrored(modification_date: nil)

    expect(result).not_to include("xmp:ModifyDate")
    expect(result).to include("xmp:CreateDate")
  end

  it "leaves a schema it was not asked about alone" do
    expect(mirrored).to include('pdfaid:part="1"')
    expect(mirrored).to include('pdfaid:conformance="B"')
  end

  it "keeps the xpacket envelope, which is what makes the packet findable" do
    expect(mirrored).to start_with("<?xpacket begin=")
    expect(mirrored.strip).to end_with("<?xpacket end=\"w\"?>")
  end

  it "escapes the characters XML cannot carry raw" do
    expect(mirrored(title: 'Ampersand & "quote" <tag>'))
      .to include("Ampersand &amp; &quot;quote&quot; &lt;tag&gt;")
  end

  describe "the XAP prefix" do
    it "uses the prefix the packet already binds" do
      legacy = packet(PdfFixtures::XMP_PACKET.gsub("xmlns:xmp=", "xmlns:xap=").gsub("<xmp:", "<xap:").gsub("</xmp:", "</xap:"))

      expect(legacy.xap_prefix).to eq("xap")
    end

    it "defaults to the modern spelling for a packet that binds neither" do
      expect(packet("<rdf:RDF></rdf:RDF>").xap_prefix).to eq("xmp")
    end
  end

  describe "a packet with no Description for the schema" do
    it "adds one rather than dropping the property" do
      bare = packet(<<~BARE)
        <x:xmpmeta xmlns:x="adobe:ns:meta/">
         <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
         </rdf:RDF>
        </x:xmpmeta>
      BARE
      result = bare.mirror(
        producer:          "P",
        creator:           "C",
        keywords:          "k",
        title:             "T",
        creation_date:     nil,
        modification_date: nil,
      )

      expect(result).to include('xmlns:pdf="http://ns.adobe.com/pdf/1.3/"')
      expect(result).to include("<pdf:Producer>P</pdf:Producer>")
      expect(result).to include("<xmp:CreatorTool>C</xmp:CreatorTool>")
      expect(result).to include('<rdf:li xml:lang="x-default">T</rdf:li>')
    end
  end

  describe "through a save" do
    around do |example|
      Dir.mktmpdir("paper-clip-xmp") do |dir|
        @dir = dir
        example.run
      end
    end

    it "rewrites the /Metadata stream of a document that has one" do
      path = PdfFixtures.with_xmp(File.join(@dir, "xmp.pdf"))
      document = PaperClip::Document.new(PdfFixtures.file_for(path))
      document.title = "Saved Title"
      document.producer = "Saved Producer"
      document.modification_date = nil
      out = File.join(@dir, "out.pdf")
      document.save(out)

      reread = PaperClip::Document.new(PdfFixtures.file_for(out))
      saved = reread.send(:xmp)
      expect(saved).to include('<rdf:li xml:lang="x-default">Saved Title</rdf:li>')
      expect(saved).to include('pdf:Producer="Saved Producer"')
      expect(saved).to include("xmp:MetadataDate")
      expect(saved).not_to include("xmp:ModifyDate")
    end

    it "leaves the Info dictionary and the packet agreeing about the title" do
      path = PdfFixtures.with_xmp(File.join(@dir, "xmp.pdf"))
      document = PaperClip::Document.new(PdfFixtures.file_for(path))
      document.title = "One Answer"
      out = File.join(@dir, "out.pdf")
      document.save(out)

      reread = PaperClip::Document.new(PdfFixtures.file_for(out))
      expect(reread.title).to eq("One Answer")
      expect(reread.send(:xmp)).to include("One Answer")
    end

    it "writes nothing extra for a document with no packet to mirror" do
      path = PdfFixtures.classic(File.join(@dir, "classic.pdf"))
      document = PaperClip::Document.new(PdfFixtures.file_for(path))
      document.title = "No Packet"
      out = File.join(@dir, "out.pdf")
      document.save(out)

      expect(File.binread(out)).not_to include("/Type /Metadata")
    end
  end
end
