# frozen_string_literal: true

require_relative "../support/translated_host"

RSpec.describe PaperClip::Translations do
  # The domain is upstream's gettext package, which is also the filename of
  # every .mo. Renaming it orphans all eighteen catalogues, and nothing else
  # in the app would fail — which is why it is pinned here.
  it "binds upstream's text domain and not the gem's name" do
    expect(described_class::TEXT_DOMAIN).to eq("pdf-metadata-editor")
  end

  it "looks for catalogues beside lib/, where the build installs them" do
    expect(described_class::LOCALE_DIR).to end_with("/locale")
  end

  describe "the markers it hands out" do
    let(:host) { TranslatedHost.new }

    it "gives includers the instance-level markers" do
      expect(host.plain).to be_a(String)
      expect(host.contextual).to be_a(String)
    end

    # N_ marks without translating; that is the whole point of using it for a
    # constant whose value is read back later.
    it "leaves an N_ marked string as its own msgid" do
      expect(host.marked_only).to eq("Printing")
    end

    it "translates a marked table entry at the point of display" do
      expect(host.translated_table_entry).to eq("Printing")
    end

    # PdfStrings marks its whole table in the module body, which only works
    # because Translations extends its includer.
    it "extends the including class so a class body can mark its constants" do
      expect(TranslatedHost::LABEL).to eq("Printing")
      expect(PaperClip::PdfStrings::PERMISSIONS.map(&:last)).to include("Printing")
      expect(PaperClip::PdfStrings::UNKNOWN).to eq("Unknown")
    end
  end

  # ruby-gettext resolves the locale from the environment once, at the first
  # lookup, and set_locale after that does not move it — so the only honest
  # way to assert on a German string is to ask a process that was started in
  # German. That is also exactly how a user gets one.
  #
  # These run only once `rake gettext:mo:update` (or the flake's installPhase)
  # has compiled po/ into locale/. Without that the lookup correctly returns
  # the msgid, and asserting on English would pass for the wrong reason.
  describe "against a compiled catalogue", if: Dir.exist?(File.expand_path("../../locale/de", __dir__)) do
    def lookup(language, marker, *arguments)
      script = <<~RUBY
        $LOAD_PATH.unshift(#{File.expand_path("../../lib", __dir__).inspect})
        $LOAD_PATH.unshift(#{File.expand_path("../support", __dir__).inspect})
        require "paper_clip/translations"
        require "translated_host"
        print TranslatedHost.new.send(#{marker.inspect}, *#{arguments.inspect})
      RUBY
      # The interpreter from PATH and not RbConfig.ruby: the packaged
      # environment puts the gems on a wrapper, and the unwrapped binary
      # RbConfig names cannot require gettext at all.
      #
      # LANGUAGE is only consulted when LC_MESSAGES is not C or POSIX, so both
      # are cleared for the child and LANGUAGE alone chooses the catalogue.
      IO.popen(
        {"LANGUAGE" => language, "LC_ALL" => nil, "LC_MESSAGES" => nil},
        ["ruby", "-e", script],
        &:read
      ).force_encoding(Encoding::UTF_8)
    end

    it "reaches upstream's German translation of a plain msgid" do
      expect(lookup("de", :_, "Open a Document")).to eq("Ein Dokument öffnen")
    end

    # The context is part of the key: without msgctxt this would fall back to
    # the English, which is the failure the shortcuts dialog had.
    it "reaches the translation keyed on (msgctxt, msgid)" do
      expect(
        lookup(
          "de",
          :p_,
          "shortcut window",
          "Close window",
        ),
      ).to eq("Fenster schließen")
    end

    it "reaches a second language, so the lookup is the catalogue and not a fluke" do
      expect(lookup("fr", :_, "Open a Document")).to eq("Ouvrir un document")
    end

    it "falls back to the msgid for a language with no catalogue" do
      expect(lookup("qq", :_, "Open a Document")).to eq("Open a Document")
    end
  end
end
