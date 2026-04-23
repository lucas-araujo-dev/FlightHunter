require "rails_helper"

RSpec.describe FlightOffer::Search::Base, type: :model do
  let(:query) do
    FlightOffer::Search::Query.from_params(
      origin_type: "airport", origin_code: "FOR",
      destination_type: "airport", destination_code: "GRU",
      trip_type: "one_way",
      departure_date_from: (Date.current + 10).to_s,
      cabin_class: "economy", passengers: 1
    )
  end

  describe "#call" do
    it "raises NotImplementedError on the base class" do
      expect { described_class.new(query).call }.to raise_error(NotImplementedError)
    end
  end

  describe "#provider_name" do
    it "raises NotImplementedError on the base class" do
      expect { described_class.new(query).provider_name }.to raise_error(NotImplementedError)
    end
  end

  describe "concrete subclass integration" do
    let(:subclass) do
      Class.new(described_class) do
        def provider_name = "test"

        def call
          timed { 1 + 1 }
          log_check(status: "success", offers_count: 2)
          build_result(status: "success", offer_ids: [1, 2])
        end
      end
    end

    it "persists a ProviderCheck on success" do
      result = subclass.call(query)
      expect(result).to be_a(FlightOffer::Search::Result)
      expect(result.status).to eq("success")
      expect(ProviderCheck.count).to eq(1)
      expect(ProviderCheck.last).to have_attributes(
        provider: "test", status: "success", offers_count: 2,
        origin_code: "FOR", destination_code: "GRU"
      )
    end

    it "truncates error_message to 1000 chars" do
      subclass_with_long_error = Class.new(described_class) do
        def provider_name = "test"

        def call
          timed { 1 }
          log_check(status: "failure", error_message: "x" * 2000)
          build_result(status: "failure", error_message: "x" * 2000)
        end
      end
      subclass_with_long_error.call(query)
      expect(ProviderCheck.last.error_message.length).to eq(1000)
    end
  end
end
