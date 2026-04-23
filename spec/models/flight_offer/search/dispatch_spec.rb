require "rails_helper"

RSpec.describe FlightOffer::Search::Dispatch, type: :model do
  let(:origin) { create(:airport, iata_code: "FOR") }
  let(:destination) { create(:airport, iata_code: "GRU") }

  let(:query) do
    origin
    destination
    FlightOffer::Search::Query.from_params(
      origin_type: "airport", origin_code: "FOR",
      destination_type: "airport", destination_code: "GRU",
      trip_type: "one_way",
      departure_date_from: (Date.current + 10).to_s,
      cabin_class: "economy", passengers: 1
    )
  end
  let(:search_id) { "search-xyz" }

  around do |example|
    original_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    example.run
    Rails.cache = original_cache
  end

  describe ".call" do
    it "enqueues DuffelJob and returns :enqueued on cache miss" do
      expect {
        expect(described_class.call(query: query, search_id: search_id)).to eq(:enqueued)
      }.to have_enqueued_job(FlightOffer::Search::DuffelJob)
        .on_queue("flight_offers")
    end

    it "delivers cached broadcast and does NOT enqueue on cache hit" do
      Rails.cache.write(query.cache_key, [42, 43])

      expect(FlightOffer::Search::Broadcast).to receive(:cached)
        .with(search_id: search_id, provider: "duffel", offer_ids: [42, 43])

      expect {
        expect(described_class.call(query: query, search_id: search_id)).to eq(:cache_hit)
      }.not_to have_enqueued_job(FlightOffer::Search::DuffelJob)
    end

    it "broadcasts empty cached state when cache hit is empty array" do
      Rails.cache.write(query.cache_key, [])
      expect(FlightOffer::Search::Broadcast).to receive(:cached)
        .with(search_id: search_id, provider: "duffel", offer_ids: [])
      described_class.call(query: query, search_id: search_id)
    end
  end
end
