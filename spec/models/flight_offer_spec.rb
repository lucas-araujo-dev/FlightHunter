require "rails_helper"

RSpec.describe FlightOffer, type: :model do
  describe "validations" do
    it "requires provider" do
      expect(build(:flight_offer, provider: nil)).not_to be_valid
    end

    it "requires offer_type" do
      expect(build(:flight_offer, offer_type: nil)).not_to be_valid
    end

    it "requires origin + destination airports" do
      expect(build(:flight_offer, origin_airport: nil)).not_to be_valid
      expect(build(:flight_offer, destination_airport: nil)).not_to be_valid
    end

    it "requires deep_link" do
      expect(build(:flight_offer, deep_link: nil)).not_to be_valid
    end
  end

  describe "enums" do
    it "accepts valid providers" do
      %w[duffel amadeus seats_aero smiles latam_pass tudoazul].each do |p|
        expect(build(:flight_offer, provider: p)).to be_valid
      end
    end

    it "rejects invalid providers" do
      expect { build(:flight_offer, provider: "lol") }.to raise_error(ArgumentError)
    end

    it "accepts offer_type cash and award" do
      expect(build(:flight_offer, offer_type: "cash")).to be_valid
      expect(build(:flight_offer, :award)).to be_valid
    end
  end

  describe "scopes" do
    let(:fortaleza) { create(:airport, iata_code: "FOR", city: "Fortaleza") }
    let(:guarulhos) { create(:airport, :sao_paulo, iata_code: "GRU") }

    it ".for_route finds by origin + destination" do
      offer = create(:flight_offer, origin_airport: fortaleza, destination_airport: guarulhos)
      create(:flight_offer, origin_airport: guarulhos, destination_airport: fortaleza)
      expect(FlightOffer.for_route(fortaleza, guarulhos)).to contain_exactly(offer)
    end

    it ".expired returns offers past expires_at" do
      old = create(:flight_offer, expires_at: 2.hours.ago)
      create(:flight_offer, expires_at: 2.hours.from_now)
      expect(FlightOffer.expired).to contain_exactly(old)
    end

    it ".cash / .award filter by offer_type" do
      cash = create(:flight_offer)
      award = create(:flight_offer, :award)
      expect(FlightOffer.cash).to contain_exactly(cash)
      expect(FlightOffer.award).to contain_exactly(award)
    end
  end

  describe "associations" do
    it { is_expected.to belong_to(:origin_airport).class_name("Airport") }
    it { is_expected.to belong_to(:destination_airport).class_name("Airport") }
    it { is_expected.to have_many(:alert_matches).dependent(:destroy) }
  end
end
