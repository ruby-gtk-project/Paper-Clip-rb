# frozen_string_literal: true

RSpec.describe PaperClip::PdfStrings do
  describe ".layout" do
    it "names each /PageLayout upstream names" do
      expect(described_class.layout("OneColumn")).to eq("Pages in one column")
      expect(described_class.layout("SinglePage")).to eq("One page at a time")
      expect(described_class.layout("TwoColumnLeft")).to eq("Odd numbered pages on the left")
      expect(described_class.layout("TwoColumnRight")).to eq("Odd numbered pages on the right")
      expect(described_class.layout("TwoPageLeft")).to eq("Two odd numbered pages on the left")
      expect(described_class.layout("TwoPageRight")).to eq("Two odd numbered pages on the right")
    end

    it "falls back for an absent or unknown layout" do
      expect(described_class.layout(nil)).to eq("No specific layout")
      expect(described_class.layout("Invented")).to eq("No specific layout")
    end
  end

  describe ".duplex" do
    it "names each /Duplex" do
      expect(described_class.duplex("DuplexFlipLongEdge")).to eq("Flip on the long edge")
      expect(described_class.duplex("DuplexFlipShortEdge")).to eq("Flip on the short edge")
      expect(described_class.duplex("Simplex")).to eq("Only single sided")
    end

    it "falls back when the document states no preference" do
      expect(described_class.duplex(nil)).to eq("No preference")
    end
  end

  describe ".subtype" do
    it "reads the standard from the XMP namespace prefix" do
      expect(described_class.subtype('xmlns:pdfaid="x" pdfaid:part="1"')).to eq("ISO 19005")
      expect(described_class.subtype("pdfeid:")).to eq("ISO 24517")
      expect(described_class.subtype("pdfuaid:")).to eq("ISO 14289")
      expect(described_class.subtype("pdfvtid:")).to eq("ISO 16612")
      expect(described_class.subtype("pdfxid:")).to eq("ISO 15930")
    end

    it "is not compliant for an empty or undeclared packet" do
      expect(described_class.subtype("")).to eq("Not compliant")
      expect(described_class.subtype(nil)).to eq("Not compliant")
      expect(described_class.subtype("<x:xmpmeta/>")).to eq("Not compliant")
    end
  end

  describe ".viewer_preferences" do
    it "lists only the preferences the dictionary actually sets" do
      expect(described_class.viewer_preferences("CenterWindow" => true, "HideMenubar" => true))
        .to eq(["Center document's window", "Hide window menubar"])
    end

    it "reads /Direction as a name and not as a boolean" do
      expect(described_class.viewer_preferences("Direction" => "R2L"))
        .to eq(["Reading order is right to left"])
      expect(described_class.viewer_preferences("Direction" => "L2R")).to eq(["No preferences"])
    end

    it "ignores a preference explicitly set to false" do
      expect(described_class.viewer_preferences("FitWindow" => false)).to eq(["No preferences"])
    end

    it "keeps upstream's order rather than the dictionary's" do
      expect(described_class.viewer_preferences("HideWindowUI" => true, "CenterWindow" => true))
        .to eq(["Center document's window", "Hide UI elements"])
    end

    it "says so when there are none" do
      expect(described_class.viewer_preferences({})).to eq(["No preferences"])
    end
  end

  # /Encrypt /P is a signed 32-bit field of *negative* permissions: a set bit
  # allows. Bit 1 is the low bit, so "printing", bit 3, is the value 4.
  describe ".permissions" do
    EVERYTHING = [
      "Adding notes",
      "Inserting elements",
      "Copying",
      "Extracting contents",
      "Filling interactive forms",
      "Modifying",
      "Printing",
      "Printing in high resolution",
    ].freeze

    it "permits everything when the document has no security handler" do
      expect(described_class.permissions(nil)).to eq(EVERYTHING)
    end

    it "maps each bit to the single permission it carries" do
      {
        32   => "Adding notes",
        1024 => "Inserting elements",
        16   => "Copying",
        512  => "Extracting contents",
        256  => "Filling interactive forms",
        8    => "Modifying",
        4    => "Printing",
        2048 => "Printing in high resolution",
      }.each do |bit, label|
        expect(described_class.permissions(bit)).to eq([label])
      end
    end

    it "permits nothing when no permission bit is set" do
      expect(described_class.permissions(0)).to eq([])
    end

    # /P arrives signed, and the two low bits are reserved and always clear,
    # so "everything allowed" is -4 rather than -1. Ruby's integers are two's
    # complement without end, so the bit tests work on the negative value
    # exactly as they do on the unsigned one — which is the only reason this
    # does not need masking to 32 bits.
    it "reads qpdf's permissive -4 as everything allowed" do
      expect(described_class.permissions(-4)).to eq(EVERYTHING)
    end

    it "reads a negative /P with printing revoked" do
      expect(described_class.permissions(-4 & ~4)).to eq(EVERYTHING - ["Printing"])
    end

    it "reads a negative /P with copying revoked" do
      expect(described_class.permissions(-4 & ~16)).to eq(EVERYTHING - ["Copying"])
    end

    it "permits everything for /P -1" do
      expect(described_class.permissions(-1)).to eq(EVERYTHING)
    end

    it "keeps upstream's enumeration order and not the numeric order" do
      expect(described_class.permissions(-1).first).to eq("Adding notes")
      expect(described_class.permissions(-1).last).to eq("Printing in high resolution")
    end
  end
end
