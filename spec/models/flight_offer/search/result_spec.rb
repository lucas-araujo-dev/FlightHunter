require "rails_helper"

RSpec.describe FlightOffer::Search::Result, type: :model do
  def build(status:, offer_ids: [], error: nil)
    described_class.new(
      status: status, offer_ids: offer_ids,
      duration_ms: 0, error_message: error, provider: "duffel"
    )
  end

  it "has canonical STATUSES" do
    expect(described_class::STATUSES).to eq(%w[success empty failure timeout cached])
  end

  it "#success? reads status" do
    expect(build(status: "success")).to be_success
    expect(build(status: "empty")).not_to be_success
  end

  it "#empty?" do
    expect(build(status: "empty")).to be_empty
  end

  it "#cached?" do
    expect(build(status: "cached")).to be_cached
  end

  it "#failed? covers failure and timeout" do
    expect(build(status: "failure")).to be_failed
    expect(build(status: "timeout")).to be_failed
    expect(build(status: "success")).not_to be_failed
  end
end
