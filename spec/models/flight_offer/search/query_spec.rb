require "rails_helper"

RSpec.describe FlightOffer::Search::Query, type: :model do
  let(:for_airport) { create(:airport, iata_code: "FOR", city: "Fortaleza", country: "BR") }
  let(:gru_airport) { create(:airport, :sao_paulo) }
  let(:cgh_airport) { create(:airport, iata_code: "CGH", city: "São Paulo", country: "BR", name: "Congonhas") }

  let(:base_params) do
    {
      origin_type: "airport", origin_code: for_airport.iata_code,
      destination_type: "airport", destination_code: gru_airport.iata_code,
      trip_type: "one_way",
      departure_date_from: (Date.current + 10).to_s,
      departure_date_to: (Date.current + 15).to_s,
      cabin_class: "economy", passengers: "1"
    }
  end

  describe ".from_params" do
    it "builds a Query with defaults" do
      query = described_class.from_params(base_params.merge(trip_type: nil, cabin_class: nil, passengers: nil))
      expect(query.trip_type).to eq("one_way")
      expect(query.cabin_class).to eq("economy")
      expect(query.passengers).to eq(1)
    end

    it "defaults departure_date_to to departure_date_from when missing" do
      params = base_params.merge(departure_date_to: nil)
      query = described_class.from_params(params)
      expect(query.departure_date_to).to eq(query.departure_date_from)
    end

    it "parses dates into Date" do
      query = described_class.from_params(base_params)
      expect(query.departure_date_from).to be_a(Date)
      expect(query.departure_date_to).to be_a(Date)
    end

    it "leaves return dates nil when absent" do
      query = described_class.from_params(base_params)
      expect(query.return_date_from).to be_nil
      expect(query.return_date_to).to be_nil
    end
  end

  describe "#round_trip? / #one_way?" do
    it "reflects trip_type" do
      expect(described_class.from_params(base_params.merge(trip_type: "round_trip"))).to be_round_trip
      expect(described_class.from_params(base_params)).to be_one_way
    end
  end

  describe "#validate!" do
    let(:future) { Date.current + 10 }

    def build(overrides)
      described_class.from_params(base_params.merge(overrides))
    end

    it "returns self when valid" do
      for_airport
      gru_airport
      expect(build({}).validate!).to be_a(described_class)
    end

    it "raises InvalidError with i18n_key on invalid origin_type" do
      for_airport
      gru_airport
      error = rescue_from_error(build(origin_type: "bogus"))
      expect(error.i18n_key).to eq("searches.errors.invalid_origin_type")
    end

    it "raises on invalid destination_type" do
      for_airport
      gru_airport
      error = rescue_from_error(build(destination_type: "bogus"))
      expect(error.i18n_key).to eq("searches.errors.invalid_destination_type")
    end

    it "raises on invalid trip_type" do
      for_airport
      gru_airport
      error = rescue_from_error(build(trip_type: "loop"))
      expect(error.i18n_key).to eq("searches.errors.invalid_trip_type")
    end

    it "raises on invalid cabin_class" do
      for_airport
      gru_airport
      error = rescue_from_error(build(cabin_class: "yacht"))
      expect(error.i18n_key).to eq("searches.errors.invalid_cabin_class")
    end

    it "raises on passengers out of range" do
      for_airport
      gru_airport
      error = rescue_from_error(build(passengers: "10"))
      expect(error.i18n_key).to eq("searches.errors.invalid_passengers")
    end

    it "raises on departure_date_from > departure_date_to" do
      for_airport
      gru_airport
      error = rescue_from_error(build(
        departure_date_from: (future + 5).to_s,
        departure_date_to: future.to_s
      ))
      expect(error.i18n_key).to eq("searches.errors.departure_range_invalid")
    end

    it "raises on past departure" do
      for_airport
      gru_airport
      error = rescue_from_error(build(
        departure_date_from: (Date.current - 1).to_s,
        departure_date_to: (Date.current - 1).to_s
      ))
      expect(error.i18n_key).to eq("searches.errors.departure_in_past")
    end

    it "raises when round_trip without return_date_from" do
      for_airport
      gru_airport
      error = rescue_from_error(build(trip_type: "round_trip", return_date_from: nil))
      expect(error.i18n_key).to eq("searches.errors.return_date_required")
    end

    it "raises when return before departure" do
      for_airport
      gru_airport
      error = rescue_from_error(build(
        trip_type: "round_trip",
        return_date_from: future.to_s,
        departure_date_from: (future + 5).to_s,
        departure_date_to: (future + 5).to_s
      ))
      expect(error.i18n_key).to eq("searches.errors.return_before_departure")
    end

    it "raises when origin has no airports" do
      gru_airport
      error = rescue_from_error(build(origin_code: "XXX"))
      expect(error.i18n_key).to eq("searches.errors.origin_has_no_airports")
    end

    it "raises when destination has no airports" do
      for_airport
      error = rescue_from_error(build(destination_code: "XXX"))
      expect(error.i18n_key).to eq("searches.errors.destination_has_no_airports")
    end

    def rescue_from_error(query)
      query.validate!
      raise "expected InvalidError"
    rescue FlightOffer::Search::Query::InvalidError => e
      e
    end
  end

  describe "#origin_airports / #destination_airports" do
    it "resolves airport type by iata_code" do
      for_airport
      query = described_class.from_params(base_params)
      expect(query.origin_airports.map(&:iata_code)).to eq(["FOR"])
    end

    it "resolves city type by 'City|Country' code" do
      gru_airport
      cgh_airport
      query = described_class.from_params(base_params.merge(
        origin_type: "city", origin_code: "São Paulo|BR"
      ))
      expect(query.origin_airports.map(&:iata_code)).to contain_exactly("GRU", "CGH")
    end
  end

  describe "#cache_key" do
    it "is deterministic for same inputs" do
      for_airport
      gru_airport
      a = described_class.from_params(base_params).cache_key
      b = described_class.from_params(base_params).cache_key
      expect(a).to eq(b)
    end

    it "differs when params differ" do
      for_airport
      gru_airport
      a = described_class.from_params(base_params).cache_key
      b = described_class.from_params(base_params.merge(cabin_class: "business")).cache_key
      expect(a).not_to eq(b)
    end

    it "starts with namespace prefix" do
      for_airport
      gru_airport
      expect(described_class.from_params(base_params).cache_key).to start_with("flight_offer:search:")
    end
  end
end
