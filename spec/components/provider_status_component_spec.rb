require "rails_helper"

RSpec.describe ProviderStatusComponent, type: :component do
  def result(status:, offer_ids: [], error: nil)
    FlightOffer::Search::Result.new(
      status: status, offer_ids: offer_ids,
      duration_ms: 0, error_message: error, provider: "duffel"
    )
  end

  it "renders success label with offer count" do
    render_inline(described_class.new(provider: "duffel", result: result(status: "success", offer_ids: [1, 2, 3])))
    expect(page).to have_content(I18n.t("searches.providers.duffel.success", count: 3))
  end

  it "renders empty label" do
    render_inline(described_class.new(provider: "duffel", result: result(status: "empty")))
    expect(page).to have_content(I18n.t("searches.providers.duffel.empty"))
  end

  it "renders failure label with error" do
    render_inline(described_class.new(provider: "duffel", result: result(status: "failure", error: "Boom")))
    expect(page).to have_content(I18n.t("searches.providers.duffel.failure", error: "Boom"))
  end

  it "renders timeout label" do
    render_inline(described_class.new(provider: "duffel", result: result(status: "timeout")))
    expect(page).to have_content(I18n.t("searches.providers.duffel.timeout"))
  end

  it "renders cached badge on cached status" do
    render_inline(described_class.new(provider: "duffel", result: result(status: "cached", offer_ids: [1])))
    expect(page).to have_content(I18n.t("searches.cached_badge"))
  end

  it "renders with stable id target" do
    render_inline(described_class.new(provider: "duffel", result: result(status: "success")))
    expect(page).to have_css("#provider_status_duffel")
  end
end
