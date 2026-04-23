require "rails_helper"

RSpec.describe FlightOffer::Search::DuffelJob, type: :job do
  let(:origin) { create(:airport, iata_code: "FOR") }
  let(:destination) { create(:airport, iata_code: "GRU") }

  let(:query_hash) do
    origin
    destination
    FlightOffer::Search::Query.from_params(
      origin_type: "airport", origin_code: "FOR",
      destination_type: "airport", destination_code: "GRU",
      trip_type: "one_way",
      departure_date_from: (Date.current + 10).to_s,
      cabin_class: "economy", passengers: 1
    ).to_h.transform_keys(&:to_s)
  end

  let(:search_id) { "s-1" }

  around do |example|
    original_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    example.run
    Rails.cache = original_cache
  end

  it "is configured on queue :flight_offers" do
    expect(described_class.new.queue_name).to eq("flight_offers")
  end

  it "rebuilds Query, calls Duffel.call, broadcasts, writes cache (success TTL)" do
    result = FlightOffer::Search::Result.new(
      status: "success", offer_ids: [101, 102],
      duration_ms: 200, error_message: nil, provider: "duffel"
    )
    expect(FlightOffer::Search::Duffel).to receive(:call)
      .with(kind_of(FlightOffer::Search::Query))
      .and_return(result)
    expect(FlightOffer::Search::Broadcast).to receive(:call)
      .with(search_id: search_id, provider: :duffel, result: result)

    described_class.perform_now(query_hash, search_id)

    cached = Rails.cache.read(FlightOffer::Search::Query.new(**query_hash.symbolize_keys).cache_key)
    expect(cached).to eq([101, 102])
  end

  it "writes shorter cache TTL when result is empty" do
    result = FlightOffer::Search::Result.new(
      status: "empty", offer_ids: [],
      duration_ms: 100, error_message: nil, provider: "duffel"
    )
    allow(FlightOffer::Search::Duffel).to receive(:call).and_return(result)
    allow(FlightOffer::Search::Broadcast).to receive(:call)

    Rails.cache = instance_double(ActiveSupport::Cache::MemoryStore)
    expect(Rails.cache).to receive(:write).with(
      an_instance_of(String),
      [],
      expires_in: FlightOffer::Search::Dispatch::CACHE_TTL_EMPTY
    )

    described_class.perform_now(query_hash, search_id)
  end
end
