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
        result = described_class.call(query: query, search_id: search_id)
        expect(result.status).to eq(:enqueued)
        expect(result.offer_ids).to be_nil
      }.to have_enqueued_job(FlightOffer::Search::DuffelJob)
        .on_queue("flight_offers")
    end

    it "returns :cache_hit with offer_ids on cache hit, without enqueuing" do
      Rails.cache.write(query.cache_key, [42, 43])

      expect {
        result = described_class.call(query: query, search_id: search_id)
        expect(result.status).to eq(:cache_hit)
        expect(result.offer_ids).to eq([42, 43])
      }.not_to have_enqueued_job(FlightOffer::Search::DuffelJob)
    end

    it "does NOT broadcast on cache hit (inline render is controller's job)" do
      Rails.cache.write(query.cache_key, [42, 43])
      expect(Turbo::StreamsChannel).not_to receive(:broadcast_append_to)
      expect(Turbo::StreamsChannel).not_to receive(:broadcast_replace_to)
      described_class.call(query: query, search_id: search_id)
    end

    it "returns empty offer_ids when cache holds an empty array" do
      Rails.cache.write(query.cache_key, [])
      result = described_class.call(query: query, search_id: search_id)
      expect(result.status).to eq(:cache_hit)
      expect(result.offer_ids).to eq([])
    end
  end
end
