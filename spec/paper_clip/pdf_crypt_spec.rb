# frozen_string_literal: true

require "tmpdir"

require_relative "../support/pdf_fixtures"

RSpec.describe PaperClip::PdfCrypt do
  FIXTURES = {
    "RC4, 40-bit (/R 2)"    => "encrypted-rc4-40.pdf",
    "RC4, 128-bit (/R 3)"   => "encrypted-rc4-128.pdf",
    "AES-128 (/R 4, AESV2)" => "encrypted-aes128.pdf",
    "AES-256 (/R 6, AESV3)" => "encrypted-aes256.pdf",
  }.freeze

  USER_PASSWORD = "secret"
  OWNER_PASSWORD = "owner"

  around do |example|
    Dir.mktmpdir("paper-clip-crypt") do |dir|
      @dir = dir
      example.run
    end
  end

  def fixture(name) = File.expand_path("../fixtures/#{name}", __dir__)

  def open_document(path, password)
    PaperClip::Document.new(PdfFixtures.file_for(path), password)
  end

  describe ".rc4" do
    # The first test vector from RFC 6229, which is the only way to know the
    # key schedule is right rather than merely self-consistent.
    it "matches the RFC 6229 test vector for a 40-bit key" do
      keystream = described_class.rc4("\x01\x02\x03\x04\x05".b, "\0" * 16)

      expect(keystream.unpack1("H*")).to start_with("b2396305f03dc027ccc3524a0a1118a8")
    end

    it "is its own inverse" do
      plain = "Secret Title"
      cipher = described_class.rc4("key", plain)

      expect(described_class.rc4("key", cipher)).to eq(plain.b)
      expect(cipher).not_to eq(plain.b)
    end
  end

  FIXTURES.each do |label, name|
    context "with #{label}" do
      it "refuses to open without a password" do
        expect { open_document(fixture(name), nil) }
          .to raise_error(PaperClip::Document::EncryptedError)
      end

      it "refuses the wrong password" do
        expect { open_document(fixture(name), "not it") }
          .to raise_error(PaperClip::Document::EncryptedError)
      end

      it "decrypts the Info dictionary with the user password" do
        document = open_document(fixture(name), USER_PASSWORD)

        expect(document.title).to eq("Secret Title")
        expect(document.author).to eq("Ada Lovelace")
        expect(document.keywords).to eq(%w[alpha beta])
      end

      it "decrypts with the owner password too" do
        expect(open_document(fixture(name), OWNER_PASSWORD).title).to eq("Secret Title")
      end

      it "re-encrypts an edit so the saved file reads back under the same password" do
        document = open_document(fixture(name), USER_PASSWORD)
        document.title = "Changed ünder encryption"
        document.add_keyword("gamma")
        out = File.join(@dir, "saved-#{name}")
        document.save(out)

        reread = open_document(out, USER_PASSWORD)
        expect(reread.title).to eq("Changed ünder encryption")
        expect(reread.keywords).to eq(%w[alpha beta gamma])
      end

      it "writes the new strings as ciphertext and not as readable literals" do
        document = open_document(fixture(name), USER_PASSWORD)
        document.title = "Plainly Visible"
        out = File.join(@dir, "cipher-#{name}")
        document.save(out)

        expect(File.binread(out)).not_to include("Plainly Visible")
      end

      it "keeps naming /Encrypt and /ID in the trailer it appends" do
        document = open_document(fixture(name), USER_PASSWORD)
        document.title = "Trailer"
        out = File.join(@dir, "trailer-#{name}")
        document.save(out)

        tail = File.binread(out)[/startxref\s+\d+\s+%%EOF\s*\z/m]
        appended = File.binread(out)[File.binread(fixture(name)).bytesize..]
        expect(tail).not_to be_nil
        expect(appended).to include("/Encrypt")
        expect(appended).to include("/ID [<")
      end

      # The fixtures were written with no restrictions, so /P is -4 and the
      # details list shows every permission. What is being pinned is that the
      # dictionary is still reachable after decryption, not the value.
      it "still reports the permissions /Encrypt /P carries" do
        expect(open_document(fixture(name), USER_PASSWORD).permissions)
          .to include("Printing", "Copying", "Modifying")
      end
    end
  end

  it "leaves an unencrypted document's strings as readable literals" do
    path = PdfFixtures.classic(File.join(@dir, "plain.pdf"))
    document = PaperClip::Document.new(PdfFixtures.file_for(path))
    document.title = "Plainly Visible"
    out = File.join(@dir, "plain-out.pdf")
    document.save(out)

    expect(File.binread(out)).to include("/Title (Plainly Visible)")
  end
end
