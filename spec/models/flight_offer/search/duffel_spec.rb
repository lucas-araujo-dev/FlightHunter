require "rails_helper"

RSpec.describe FlightOffer::Search::Duffel, type: :model do
  let!(:for_airport) { create(:airport, iata_code: "FOR", city: "Fortaleza", country: "BR") }
  let!(:gru_airport) { create(:airport, :sao_paulo) }

  let(:query) do
    FlightOffer::Search::Query.from_params(
      origin_type: "airport", origin_code: "FOR",
      destination_type: "airport", destination_code: "GRU",
      trip_type: "one_way",
      departure_date_from: "2026-05-15",
      cabin_class: "economy", passengers: 1
    )
  end

  before do
    allow(Rails.application.credentials).to receive(:dig).and_call_original
    allow(Rails.application.credentials).to receive(:dig).with(:duffel, :api_key).and_return("duffel_test_stub_for_cassettes")
  end

  describe "#call — success path",
    vcr: {cassette_name: "flight_offer/search/duffel/success_one_way_for_gru",
          match_requests_on: [:method, :host, :path]} do
    it "persists FlightOffers and returns success Result" do
      result = described_class.call(query)

      expect(result).to be_a(FlightOffer::Search::Result)
      expect(result.status).to eq("success")
      expect(result.provider).to eq("duffel")
      expect(result.offer_ids).to be_present

      offer = FlightOffer.find(result.offer_ids.first)
      expect(offer.provider).to eq("duffel")
      expect(offer.provider_offer_id).to be_present
      expect(offer.offer_type).to eq("cash")
      expect(offer.origin_airport).to eq(for_airport)
      expect(offer.destination_airport).to eq(gru_airport)
      expect(offer.price_cents).to be_positive
      expect(offer.currency).to be_present
      expect(offer.deep_link).to start_with("https://app.duffel.com/offers/")
    end

    it "creates a ProviderCheck success row" do
      described_class.call(query)
      check = ProviderCheck.last
      expect(check).to have_attributes(
        provider: "duffel", status: "success",
        origin_code: "FOR", destination_code: "GRU"
      )
      expect(check.offers_count).to be_positive
    end

    it "is idempotent on repeated calls (no duplicate rows)" do
      described_class.call(query)
      count_after_first = FlightOffer.count
      described_class.call(query)
      expect(FlightOffer.count).to eq(count_after_first)
    end
  end
end
