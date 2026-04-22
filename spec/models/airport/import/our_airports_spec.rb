require "rails_helper"

RSpec.describe Airport::Import::OurAirports, type: :model do
  let(:fixture_path) { Rails.root.join("spec/fixtures/our_airports/airports_sample.csv") }

  describe ".call with local fixture" do
    it "imports the expected number of airports" do
      count_before = Airport.count
      File.open(fixture_path) do |io|
        described_class.call(io: io)
      end
      expect(Airport.count - count_before).to eq(15)
    end

    it "excludes heliport, closed and seaplane_base types" do
      File.open(fixture_path) { |io| described_class.call(io: io) }
      expect(Airport.where(airport_type: "heliport")).to be_empty
      expect(Airport.where(airport_type: "closed")).to be_empty
      expect(Airport.where(airport_type: "seaplane_base")).to be_empty
    end

    it "skips rows without iso_country" do
      File.open(fixture_path) { |io| described_class.call(io: io) }
      expect(Airport.where(name: "No country")).to be_empty
    end

    it "skips rows with empty ident (icao_code is the unique_by key)" do
      File.open(fixture_path) { |io| described_class.call(io: io) }
      expect(Airport.find_by(name: "Unregistered strip")).to be_nil
    end

    it "maps columns correctly" do
      File.open(fixture_path) { |io| described_class.call(io: io) }
      fortaleza = Airport.find_by(icao_code: "SBFZ")
      expect(fortaleza).to have_attributes(
        iata_code: "FOR",
        name: "Pinto Martins International Airport",
        city: "Fortaleza",
        country: "BR",
        airport_type: "large_airport"
      )
      expect(fortaleza.latitude).to be_within(0.001).of(-3.776282)
    end

    it "persists nil iata_code for airports without it" do
      File.open(fixture_path) { |io| described_class.call(io: io) }
      torres = Airport.find_by(icao_code: "SSTR")
      expect(torres).to be_present
      expect(torres.iata_code).to be_nil
    end

    it "is idempotent when run twice with same input" do
      File.open(fixture_path) { |io| described_class.call(io: io) }
      first_count = Airport.count
      File.open(fixture_path) { |io| described_class.call(io: io) }
      expect(Airport.count).to eq(first_count)
    end
  end

  describe ".source_url" do
    around do |example|
      original = ENV.delete("OUR_AIRPORTS_URL")
      example.run
    ensure
      ENV["OUR_AIRPORTS_URL"] = original if original
    end

    it "falls back to the default URL when ENV is not set" do
      expect(described_class.source_url).to eq(Airport::Import::OurAirports::DEFAULT_SOURCE_URL)
    end

    it "reads from ENV when OUR_AIRPORTS_URL is set" do
      ENV["OUR_AIRPORTS_URL"] = "https://example.com/custom.csv"
      expect(described_class.source_url).to eq("https://example.com/custom.csv")
    end
  end
end
