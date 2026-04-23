require "rails_helper"

RSpec.describe FlightOffer::Search::Broadcast, type: :model do
  let(:origin) { create(:airport, iata_code: "FOR") }
  let(:destination) { create(:airport, iata_code: "GRU") }
  let(:offer) do
    create(:flight_offer, origin_airport: origin, destination_airport: destination)
  end
  let(:search_id) { "search-abc" }
  let(:stream_key) { "flight_offer_search_#{search_id}" }

  def result(status:, offer_ids: [], error: nil)
    FlightOffer::Search::Result.new(
      status: status, offer_ids: offer_ids,
      duration_ms: 0, error_message: error, provider: "duffel"
    )
  end

  describe ".call — success" do
    it "broadcasts one append per offer plus one replace for status" do
      offer
      expect(Turbo::StreamsChannel)
        .to receive(:broadcast_append_to)
        .with(stream_key, hash_including(target: "flight_offer_cards"))
        .once
      expect(Turbo::StreamsChannel)
        .to receive(:broadcast_replace_to)
        .with(stream_key, hash_including(target: "provider_status_duffel"))
        .once

      described_class.call(
        search_id: search_id, provider: :duffel,
        result: result(status: "success", offer_ids: [offer.id])
      )
    end
  end

  describe ".call — empty" do
    it "broadcasts only the status replace" do
      expect(Turbo::StreamsChannel).not_to receive(:broadcast_append_to)
      expect(Turbo::StreamsChannel)
        .to receive(:broadcast_replace_to)
        .with(stream_key, hash_including(target: "provider_status_duffel"))
        .once

      described_class.call(search_id: search_id, provider: :duffel, result: result(status: "empty"))
    end
  end

  describe ".call — failure" do
    it "broadcasts only the status replace with failure styling" do
      expect(Turbo::StreamsChannel).not_to receive(:broadcast_append_to)
      expect(Turbo::StreamsChannel).to receive(:broadcast_replace_to).once
      described_class.call(search_id: search_id, provider: :duffel,
        result: result(status: "failure", error: "Boom"))
    end
  end
end
