require "rails_helper"

RSpec.describe SearchResultsComponent, type: :component do
  it "renders the search_results container" do
    render_inline(described_class.new(search_id: "abc"))
    expect(page).to have_css("#search_results")
  end

  it "renders a turbo-cable-stream-source element" do
    render_inline(described_class.new(search_id: "abc"))
    expect(page.native.to_s).to include("turbo-cable-stream-source")
    expect(page.native.to_s).to include('channel="Turbo::StreamsChannel"')
  end

  it "renders a provider_status_<provider> placeholder per provider" do
    render_inline(described_class.new(search_id: "abc"))
    described_class::PROVIDERS.each do |p|
      expect(page).to have_css("#provider_status_#{p}")
      expect(page).to have_content(I18n.t("searches.providers.#{p}.searching"))
    end
  end

  it "renders an empty flight_offer_cards container" do
    render_inline(described_class.new(search_id: "abc"))
    expect(page).to have_css("#flight_offer_cards")
  end

  it "has PROVIDERS aligned with Dispatch::PROVIDERS" do
    expect(described_class::PROVIDERS).to eq(FlightOffer::Search::Dispatch::PROVIDERS)
  end
end
