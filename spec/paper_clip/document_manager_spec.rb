# frozen_string_literal: true

require "tmpdir"

require_relative "../support/pdf_fixtures"

RSpec.describe PaperClip::DocumentManager do
  around do |example|
    Dir.mktmpdir("paper-clip-manager") do |dir|
      @dir = dir
      example.run
    end
  end

  let(:manager) { described_class.new }

  def document(name = "classic.pdf")
    PaperClip::Document.new(PdfFixtures.file_for(PdfFixtures.classic(File.join(@dir, name))))
  end

  it "starts with no document and nothing to save" do
    expect(manager.document).to be_nil
    expect(manager.changed?).to be(false)
  end

  it "is clean the moment a document is assigned" do
    manager.document = document

    expect(manager.changed?).to be(false)
  end

  it "becomes dirty when the document reports a change" do
    manager.document = document
    manager.document.title = "Edited"

    expect(manager.changed?).to be(true)
  end

  it "stays clean when an edit changes nothing" do
    manager.document = document
    manager.document.title = "Secret Title"

    expect(manager.changed?).to be(false)
  end

  it "becomes dirty when a keyword is added" do
    manager.document = document
    manager.document.add_keyword("gamma")

    expect(manager.changed?).to be(true)
  end

  it "forgets the previous document's dirty flag when a new one arrives" do
    manager.document = document("one.pdf")
    manager.document.title = "Edited"
    manager.document = document("two.pdf")

    expect(manager.changed?).to be(false)
  end

  it "does not follow the previous document's changes once replaced" do
    first = document("one.pdf")
    manager.document = first
    manager.document = document("two.pdf")
    first.title = "Edited behind its back"

    expect(manager.changed?).to be(false)
  end

  it "takes a nil document without complaining, as a closed window does" do
    manager.document = document
    manager.document = nil

    expect(manager.document).to be_nil
    expect(manager.changed?).to be(false)
  end
end
