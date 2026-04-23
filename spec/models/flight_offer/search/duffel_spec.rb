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

  describe "#call — empty offers",
    vcr: {cassette_name: "flight_offer/search/duffel/empty_offers",
          match_requests_on: [:method, :host, :path]} do
    it "returns empty Result and logs success with 0 offers" do
      result = described_class.call(query)
      expect(result.status).to eq("empty")
      expect(result.offer_ids).to eq([])
      expect(ProviderCheck.last).to have_attributes(status: "success", offers_count: 0)
    end
  end

  describe "#call — HTTP 429",
    vcr: {cassette_name: "flight_offer/search/duffel/http_429",
          match_requests_on: [:method, :host, :path]} do
    it "returns failure Result and logs rate_limited" do
      result = described_class.call(query)
      expect(result.status).to eq("failure")
      expect(result.error_message).to match(/rate limit/i)
      expect(ProviderCheck.last.status).to eq("rate_limited")
    end
  end

  describe "#call — HTTP 500",
    vcr: {cassette_name: "flight_offer/search/duffel/http_500",
          match_requests_on: [:method, :host, :path]} do
    it "returns failure Result with error_message preenchido" do
      result = described_class.call(query)
      expect(result.status).to eq("failure")
      expect(result.error_message).to match(/Duffel HTTP 500/)
      expect(ProviderCheck.last.status).to eq("failure")
    end
  end

  describe "#call — timeout" do
    before { stub_request(:post, %r{api\.duffel\.com/air/offer_requests}).to_timeout }

    it "returns timeout Result and logs failure" do
      result = described_class.call(query)
      expect(result.status).to eq("timeout")
      expect(ProviderCheck.last.status).to eq("failure")
    end
  end

  describe "#call — round trip",
    vcr: {cassette_name: "flight_offer/search/duffel/success_round_trip",
          match_requests_on: [:method, :host, :path]} do
    let(:query) do
      FlightOffer::Search::Query.from_params(
        origin_type: "airport", origin_code: "FOR",
        destination_type: "airport", destination_code: "GRU",
        trip_type: "round_trip",
        departure_date_from: "2026-05-15",
        return_date_from: "2026-05-22",
        cabin_class: "economy", passengers: 1
      )
    end

    it "populates return_departure_at / return_arrival_at on the persisted offer" do
      result = described_class.call(query)
      offer = FlightOffer.find(result.offer_ids.first)
      expect(offer.return_departure_at).to be_present
      expect(offer.return_arrival_at).to be_present
    end
  end

  describe "#call — missing credentials" do
    before do
      allow(Rails.application.credentials).to receive(:dig).with(:duffel, :api_key).and_return(nil)
    end

    it "captures as failure (rescued as StandardError)" do
      result = described_class.call(query)
      expect(result.status).to eq("failure")
      expect(result.error_message).to match(/Duffel credentials ausentes/)
      expect(ProviderCheck.last.status).to eq("failure")
    end
  end

  describe "#call — unknown airport IATA in response",
    vcr: {cassette_name: "flight_offer/search/duffel/unknown_airport",
          match_requests_on: [:method, :host, :path]} do
    it "skips the offer with unknown IATA and persists the rest" do
      result = described_class.call(query)
      expect(result.status).to eq("success")
      expect(FlightOffer.pluck(:airline_iata)).to all(be_present)
    end
  end
end
