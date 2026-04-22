require "rails_helper"

RSpec.describe Airport, type: :model do
  describe "validations" do
    it "requires name" do
      expect(build(:airport, name: nil)).not_to be_valid
    end

    it "requires country" do
      expect(build(:airport, country: nil)).not_to be_valid
    end

    it "allows nil iata_code" do
      expect(build(:airport, iata_code: nil)).to be_valid
    end

    it "enforces unique iata_code when present" do
      create(:airport, iata_code: "FOR")
      expect(build(:airport, iata_code: "FOR")).not_to be_valid
    end

    it "allows multiple airports with nil iata_code" do
      create(:airport, iata_code: nil, icao_code: "XXXX")
      expect(build(:airport, iata_code: nil, icao_code: "YYYY")).to be_valid
    end
  end

  describe ".in_city scope" do
    it "groups airports by city + country" do
      create(:airport, :sao_paulo, iata_code: "GRU")
      create(:airport, city: "São Paulo", country: "BR", iata_code: "CGH")
      create(:airport, :sao_paulo, iata_code: "VCP")
      results = Airport.where(city: "São Paulo", country: "BR")
      expect(results.count).to eq(3)
    end
  end
end
