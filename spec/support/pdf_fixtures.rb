# frozen_string_literal: true

require "fileutils"
require "tmpdir"

# PdfFixtures writes the PDFs the suite parses.
#
# They are built here rather than committed because every one of them is a
# handful of objects whose byte offsets have to agree with their own
# cross-reference table: a generator that computes the offsets cannot drift
# out of step with the bytes the way a committed binary can.
module PdfFixtures
  INFO = "<< /Title (Secret Title) /Author (Ada Lovelace) /Keywords (alpha,beta) " \
         "/Creator (Hand) /Producer (Hand) /CreationDate (D:20240115103000+00'00') >>"

  XMP_PACKET = <<~PACKET.freeze
    <?xpacket begin="" id="W5M0MpCehiHzreSzNTczkc9d"?>
    <x:xmpmeta xmlns:x="adobe:ns:meta/">
     <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
      <rdf:Description rdf:about="" xmlns:pdf="http://ns.adobe.com/pdf/1.3/" pdf:Producer="Old Producer"/>
      <rdf:Description rdf:about="" xmlns:dc="http://purl.org/dc/elements/1.1/">
       <dc:title><rdf:Alt><rdf:li xml:lang="x-default">Old XMP Title</rdf:li></rdf:Alt></dc:title>
      </rdf:Description>
      <rdf:Description rdf:about="" xmlns:xmp="http://ns.adobe.com/xap/1.0/" xmlns:pdfaid="http://www.aiim.org/pdfa/ns/id/" pdfaid:part="1" pdfaid:conformance="B">
       <xmp:CreateDate>2001-02-03T04:05:06+00:00</xmp:CreateDate>
       <xmp:ModifyDate>2001-02-03T04:05:06+00:00</xmp:ModifyDate>
       <xmp:CreatorTool>Old Tool</xmp:CreatorTool>
      </rdf:Description>
     </rdf:RDF>
    </x:xmpmeta>
    <?xpacket end="w"?>
  PACKET

  ID = "[<0123456789ABCDEF0123456789ABCDEF> <0123456789ABCDEF0123456789ABCDEF>]"

  # A classic file: `trailer` keyword, plain xref table, one page.
  def self.classic(path, info: INFO)
    objects = [
      "<< /Type /Catalog /Pages 2 0 R >>",
      "<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
      "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 200 200] >>",
      info,
    ]
    write(path, build(objects, "/Size 5 /Root 1 0 R /Info 4 0 R /ID #{ID}"))
  end

  # The same file with a registered /Metadata stream, so has_xmp? is true and
  # a save has a packet to mirror into.
  def self.with_xmp(path)
    objects = [
      "<< /Type /Catalog /Pages 2 0 R /Metadata 5 0 R >>",
      "<< /Type /Pages /Kids [3 0 R] /Count 2 >>",
      "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 200 200] >>",
      INFO,
      stream_object(XMP_PACKET),
    ]
    write(path, build(objects, "/Size 6 /Root 1 0 R /Info 4 0 R /ID #{ID}"))
  end

  # A file whose page tree declares no count and holds no /Type /Page object,
  # which is what makes DetailsList hide the page-count row.
  def self.pageless(path)
    objects = [
      "<< /Type /Catalog >>",
      INFO,
    ]
    write(path, build(objects, "/Size 3 /Root 1 0 R /Info 2 0 R /ID #{ID}"))
  end

  # A page big and dark enough to prove the downscaled-PNG branch of
  # Thumbnailer actually renders the document rather than drawing nothing.
  # 600×600 clears `DocumentThumbnail::MAX_SIZE` (350) squared times
  # Thumbnailer::AREA_THRESHOLD (2.5) — 306,250 — so this is the file the
  # drive harness hands to the PNG-cache path, not the in-memory one. The
  # content stream fills the bottom half black with the page's default fill
  # colour, so a render that drew nothing (a white rectangle) is
  # distinguishable, pixel for pixel, from a render that drew this page.
  def self.big(path, info: INFO)
    content = "0 0 600 300 re f\n"
    objects = [
      "<< /Type /Catalog /Pages 2 0 R >>",
      "<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
      "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 600 600] /Contents 5 0 R >>",
      info,
      page_content_stream(content),
    ]
    write(path, build(objects, "/Size 6 /Root 1 0 R /Info 4 0 R /ID #{ID}"))
  end

  def self.page_content_stream(payload)
    "<< /Length #{payload.bytesize} >>\nstream\n#{payload}\nendstream"
  end

  def self.stream_object(payload)
    "<< /Type /Metadata /Subtype /XML /Length #{payload.bytesize} >>\nstream\n#{payload}\nendstream"
  end

  def self.build(objects, trailer)
    (+"%PDF-1.7\n").tap do |body|
      offsets = []
      objects.each_with_index do |object, index|
        offsets << body.bytesize
        body << "#{index + 1} 0 obj\n#{object}\nendobj\n"
      end
      start = body.bytesize
      body << "xref\n0 #{objects.length + 1}\n0000000000 65535 f \n"
      offsets.each { |offset| body << "#{offset.to_s.rjust(10, "0")} 00000 n \n" }
      body << "trailer\n<< #{trailer} >>\nstartxref\n#{start}\n%%EOF\n"
    end
  end

  def self.write(path, bytes)
    FileUtils.mkdir_p(File.dirname(path))
    File.binwrite(path, bytes)
    path
  end

  # Document takes a Gio::File, which is all it uses the original for.
  def self.file_for(path) = Gio::File.new_for_path(path)
end
