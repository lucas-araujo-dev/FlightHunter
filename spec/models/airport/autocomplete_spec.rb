require "rails_helper"

RSpec.describe Airport::Autocomplete, type: :model do
  describe ".call" do
    it "returns empty array for query shorter than 2 chars" do
      expect(described_class.call("")).to eq([])
      expect(described_class.call("f")).to eq([])
    end

    it "finds airport by IATA prefix" do
      create(:airport, iata_code: "FOR", name: "Pinto Martins", city: "Fortaleza", country: "BR")
      results = described_class.call("for")
      expect(results.first.type).to eq("airport")
      expect(results.first.code).to eq("FOR")
      expect(results.first.display).to include("FOR")
    end

    it "finds airport by name substring" do
      create(:airport, iata_code: "GRU", name: "Guarulhos International", city: "São Paulo", country: "BR")
      results = described_class.call("guarulhos")
      expect(results.map(&:code)).to include("GRU")
    end

    it "aggregates cities with >= min_city_airports" do
      create(:airport, iata_code: "GRU", city: "São Paulo", country: "BR", name: "Guarulhos")
      create(:airport, iata_code: "CGH", city: "São Paulo", country: "BR", name: "Congonhas")
      create(:airport, iata_code: "VCP", city: "São Paulo", country: "BR", name: "Viracopos")

      results = described_class.call("são paulo")
      city = results.find { |r| r.type == "city" }
      expect(city).to be_present
      expect(city.code).to eq("São Paulo|BR")
      expect(city.display).to match(/São Paulo \(\d+ airports\)/)
    end

    it "does not aggregate city with single airport" do
      create(:airport, iata_code: "FOR", city: "Fortaleza", country: "BR", name: "Pinto Martins")
      results = described_class.call("fortaleza")
      expect(results.any? { |r| r.type == "city" }).to be false
    end

    it "ranks IATA prefix matches above name substring matches" do
      create(:airport, iata_code: "FOR", name: "Fortaleza airport", city: "Fortaleza", country: "BR")
      create(:airport, iata_code: "XXX", name: "Some Fort", city: "Other", country: "US")
      results = described_class.call("for")
      expect(results.first.code).to eq("FOR")
    end

    it "respects limit" do
      5.times { |i| create(:airport, iata_code: "A#{i}#{i}", name: "Airport #{i}", city: "City#{i}", country: "BR") }
      results = described_class.call("airport", limit: 2)
      expect(results.size).to be <= 2
    end

    it "returns Result with to_h usable as JSON" do
      create(:airport, iata_code: "FOR", name: "Pinto Martins", city: "Fortaleza", country: "BR")
      result = described_class.call("for").first
      expect(result.to_h.keys).to contain_exactly(:type, :code, :display, :secondary)
    end
  end
end
