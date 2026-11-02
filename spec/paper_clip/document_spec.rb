# frozen_string_literal: true

require "time"
require "tmpdir"

require_relative "../support/pdf_fixtures"

RSpec.describe PaperClip::Document do
  around do |example|
    Dir.mktmpdir("paper-clip-spec") do |dir|
      @dir = dir
      example.run
    end
  end

  def open_document(path, password = nil)
    described_class.new(PdfFixtures.file_for(path), password)
  end

  def classic(name = "classic.pdf", **options)
    PdfFixtures.classic(File.join(@dir, name), **options)
  end

  describe ".parse_date" do
    it "reads a full PDF date string" do
      expect(described_class.parse_date("D:20240115103000+00'00'"))
        .to eq(
          Time.parse("2024-01-15 10:30:00"),
        )
    end

    it "defaults every field after the year" do
      expect(described_class.parse_date("D:1999")).to eq(
        Time.parse("1999-01-01 00:00:00"),
      )
    end

    it "accepts the D: prefix, the bare colon and neither" do
      [
        "D:20240115",
        ":20240115",
        "20240115",
      ].each do |raw|
        expect(described_class.parse_date(raw)).to eq(
          Time.parse("2024-01-15 00:00:00"),
        )
      end
    end

    it "reads a partial date down to the month" do
      expect(described_class.parse_date("D:202402")).to eq(
        Time.parse("2024-02-01 00:00:00"),
      )
    end

    it "is nil for a string with no year in it" do
      expect(described_class.parse_date("not a date")).to be_nil
    end

    it "is nil for nil, so a missing /CreationDate is a missing date" do
      expect(described_class.parse_date(nil)).to be_nil
    end

    # The regexp is anchored, so trailing junk is ignored and leading junk is
    # not a date at all.
    it "ignores trailing junk but refuses leading junk" do
      expect(described_class.parse_date("D:20240115103000Z00'00' and more"))
        .to eq(
          Time.parse("2024-01-15 10:30:00"),
        )
      expect(described_class.parse_date("x D:20240115")).to be_nil
    end
  end

  describe ".format_date" do
    it "writes the offset with PDF's apostrophes" do
      expect(
        described_class.format_date(
          Time.parse("2024-01-15T10:30:00+00:00"),
        ),
      )
        .to eq("D:20240115103000+00'00'")
    end

    it "round-trips through parse_date" do
      time = Time.parse("2024-06-01 23:59:58")
      expect(described_class.parse_date(described_class.format_date(time))).to eq(time)
    end
  end

  describe "the cached copy" do
    it "parses a copy in $TMPDIR/copies and not the original" do
      path = classic
      document = open_document(path)

      expect(document.cached_path).not_to eq(path)
      expect(document.cached_path).to start_with(File.join(Dir.tmpdir, "copies"))
      expect(File.binread(document.cached_path)).to eq(File.binread(path))
    end

    it "leaves the original untouched when a save is written elsewhere" do
      path = classic
      before = File.binread(path)
      document = open_document(path)
      document.title = "Changed"
      document.save(File.join(@dir, "out.pdf"))

      expect(File.binread(path)).to eq(before)
    end

    it "exposes the copy as a Gio::File, as upstream's cached_file does" do
      document = open_document(classic)

      expect(document.cached_file.path).to eq(document.cached_path)
    end
  end

  describe "reading" do
    it "reads the Info dictionary" do
      document = open_document(classic)

      expect(document.title).to eq("Secret Title")
      expect(document.author).to eq("Ada Lovelace")
      expect(document.creator).to eq("Hand")
      expect(document.producer).to eq("Hand")
      expect(document.creation_date).to eq(
        Time.parse("2024-01-15 10:30:00"),
      )
      expect(document.modification_date).to be_nil
    end

    it "reports the header version as the format" do
      expect(open_document(classic).format).to eq("PDF-1.7")
    end

    it "counts pages from /Pages /Count" do
      expect(open_document(classic).n_pages).to eq(1)
    end

    it "reports no pages for a file with no page tree it can follow" do
      expect(open_document(PdfFixtures.pageless(File.join(@dir, "pageless.pdf"))).n_pages).to eq(0)
    end

    it "has no XMP packet when the catalog registers no /Metadata stream" do
      expect(open_document(classic).has_xmp?).to be(false)
    end

    it "reads the XMP packet when there is one" do
      document = open_document(PdfFixtures.with_xmp(File.join(@dir, "xmp.pdf")))

      expect(document.has_xmp?).to be(true)
      expect(document.subtype).to eq("ISO 19005")
    end
  end

  describe "keywords" do
    it "splits /Keywords on commas and trims each one" do
      path = classic(info: "<< /Keywords ( alpha , beta ,, gamma ) >>")

      expect(open_document(path).keywords).to eq(%w[alpha beta gamma])
    end

    it "is empty when the document has no /Keywords" do
      expect(open_document(classic(info: "<< /Title (T) >>")).keywords).to eq([])
    end

    it "round-trips through a save, comma-joined" do
      document = open_document(classic)
      document.add_keyword("gamma")
      out = File.join(@dir, "out.pdf")
      document.save(out)

      expect(open_document(out).keywords).to eq(%w[alpha beta gamma])
    end

    it "drops a blank keyword on the way out rather than writing an empty slot" do
      document = open_document(classic)
      document.add_keyword("")
      out = File.join(@dir, "out.pdf")
      document.save(out)

      expect(open_document(out).keywords).to eq(%w[alpha beta])
    end

    it "writes no /Keywords at all when every keyword has gone" do
      document = open_document(classic)
      document.keywords.length.times { document.remove_keyword_at(0) }
      out = File.join(@dir, "out.pdf")
      document.save(out)

      expect(open_document(out).keywords).to eq([])
    end

    it "removes by value through the first match" do
      document = open_document(classic)
      document.remove_keyword("alpha")

      expect(document.keywords).to eq(%w[beta])
    end

    it "ignores a removal of a keyword that is not there" do
      document = open_document(classic)
      document.remove_keyword("zeta")

      expect(document.keywords).to eq(%w[alpha beta])
    end

    describe "the items-changed notification" do
      it "carries position, removed and added when a keyword is added" do
        document = open_document(classic)
        seen = []
        document.on_keywords_changed { |*args| seen << args }
        document.add_keyword("gamma")

        expect(seen).to eq([[2, 0, 1]])
      end

      it "carries the index that went away when one is removed" do
        document = open_document(classic)
        seen = []
        document.on_keywords_changed { |*args| seen << args }
        document.remove_keyword_at(0)

        expect(seen).to eq([[0, 1, 0]])
      end

      # This is the whole reason the notification is separate from on_change:
      # a row being typed into must not be rebuilt under the cursor.
      it "is silent when a keyword's text is edited" do
        document = open_document(classic)
        seen = []
        document.on_keywords_changed { |*args| seen << args }
        document.update_keyword(0, "renamed")

        expect(seen).to be_empty
        expect(document.keywords).to eq(%w[renamed beta])
      end

      it "is silent when an edit changes nothing" do
        document = open_document(classic)
        changed = false
        document.on_change { changed = true }
        document.update_keyword(0, "alpha")

        expect(changed).to be(false)
      end
    end
  end

  describe "change notification" do
    it "fires when an Info entry actually changes" do
      document = open_document(classic)
      changed = false
      document.on_change { changed = true }
      document.title = "Different"

      expect(changed).to be(true)
    end

    it "stays silent when an entry is set to the value it already had" do
      document = open_document(classic)
      changed = false
      document.on_change { changed = true }
      document.title = "Secret Title"

      expect(changed).to be(false)
    end

    it "fires when a date is cleared" do
      document = open_document(classic)
      changed = false
      document.on_change { changed = true }
      document.creation_date = nil

      expect(changed).to be(true)
    end
  end

  describe "the incremental-update writer" do
    it "keeps every original byte and appends" do
      path = classic
      original = File.binread(path)
      document = open_document(path)
      document.title = "Appended"
      out = File.join(@dir, "out.pdf")
      document.save(out)

      saved = File.binread(out)
      expect(saved.byteslice(0, original.bytesize)).to eq(original)
      expect(saved.bytesize).to be > original.bytesize
    end

    it "chains to the previous startxref through /Prev" do
      path = classic
      previous = File.binread(path)[/startxref\s+(\d+)/, 1].to_i
      document = open_document(path)
      document.title = "Chained"
      out = File.join(@dir, "out.pdf")
      document.save(out)

      expect(File.binread(out)).to include("/Prev #{previous}")
    end

    it "writes a classic xref table for a file that has one" do
      document = open_document(classic)
      document.title = "Table"
      out = File.join(@dir, "out.pdf")
      document.save(out)

      tail = File.binread(out)[/xref.*\z/m]
      expect(tail).to start_with("xref\n")
      expect(tail).to include("trailer")
    end

    # Twenty bytes per entry is not decoration: a reader seeks into the table
    # by multiplying the object number by the entry width.
    it "writes twenty-byte xref entries" do
      document = open_document(classic)
      document.title = "Width"
      out = File.join(@dir, "out.pdf")
      document.save(out)

      entry = File.binread(out)[/^(\d{10} \d{5} n \n)/, 1]
      expect(entry.bytesize).to eq(20)
    end

    it "points the new xref entry at the object it describes" do
      path = classic
      original_size = File.size(path)
      document = open_document(path)
      document.title = "Offset"
      out = File.join(@dir, "out.pdf")
      document.save(out)

      saved = File.binread(out)
      appended = saved.byteslice(original_size..)
      number = appended[/(\d+) 0 obj/, 1].to_i
      offset = appended[/^(\d{10}) \d{5} n \n/, 1].to_i
      expect(saved.byteslice(offset, 32)).to start_with("#{number} 0 obj")
    end

    it "makes the appended Info dictionary the one that is read back" do
      document = open_document(classic)
      document.title = "Winner"
      document.author = ""
      out = File.join(@dir, "out.pdf")
      document.save(out)

      reread = open_document(out)
      expect(reread.title).to eq("Winner")
      expect(reread.author).to eq("")
    end

    it "survives being saved twice, each update chaining to the last" do
      first = File.join(@dir, "first.pdf")
      second = File.join(@dir, "second.pdf")
      document = open_document(classic)
      document.title = "One"
      document.save(first)

      reopened = open_document(first)
      reopened.title = "Two"
      reopened.save(second)

      expect(open_document(second).title).to eq("Two")
    end

    it "writes non-ASCII as UTF-16BE behind a byte-order mark" do
      document = open_document(classic)
      document.title = "Žluťoučký"
      out = File.join(@dir, "out.pdf")
      document.save(out)

      expect(File.binread(out)).to include("/Title <FEFF")
      expect(open_document(out).title).to eq("Žluťoučký")
    end

    it "escapes the characters a literal string cannot carry raw" do
      document = open_document(classic)
      document.title = 'a(b)c\\d'
      out = File.join(@dir, "out.pdf")
      document.save(out)

      expect(open_document(out).title).to eq('a(b)c\\d')
    end
  end
end
