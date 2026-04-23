require "rails_helper"

RSpec.describe SearchResultsComponent, type: :component do
  describe "streaming (cache miss)" do
    it "renders the search_results container" do
      render_inline(described_class.new(search_id: "abc"))
      expect(page).to have_css("#search_results")
    end

    it "renders a turbo-cable-stream-source element" do
      render_inline(described_class.new(search_id: "abc"))
      expect(page.native.to_s).to include("turbo-cable-stream-source")
      expect(page.native.to_s).to include('channel="Turbo::StreamsChannel"')
    end

    it "renders a provider_status_<provider> placeholder per provider with 'searching' label" do
      render_inline(described_class.new(search_id: "abc"))
      described_class::PROVIDERS.each do |p|
        expect(page).to have_css("#provider_status_#{p}")
        expect(page).to have_content(I18n.t("searches.providers.#{p}.searching"))
      end
    end

    it "renders an empty flight_offer_cards container" do
      render_inline(described_class.new(search_id: "abc"))
      expect(page).to have_css("#flight_offer_cards", text: "")
    end

    it "has PROVIDERS aligned with Dispatch::PROVIDERS" do
      expect(described_class::PROVIDERS).to eq(FlightOffer::Search::Dispatch::PROVIDERS)
    end
  end

  describe "inline render (cache hit)" do
    let!(:origin) { create(:airport, iata_code: "FOR") }
    let!(:destination) { create(:airport, iata_code: "GRU") }
    let!(:offer) do
      create(:flight_offer,
        origin_airport: origin, destination_airport: destination,
        airline_iata: "AD", stops: 0, price_cents: 75_000, currency: "BRL")
    end

    it "does NOT render turbo-cable-stream-source on cache hit" do
      render_inline(described_class.new(search_id: "abc", cached_offer_ids: [offer.id]))
      expect(page.native.to_s).not_to include("turbo-cable-stream-source")
    end

    it "renders cached cards inline under flight_offer_cards" do
      render_inline(described_class.new(search_id: "abc", cached_offer_ids: [offer.id]))
      expect(page).to have_css("#flight_offer_cards article")
      expect(page).to have_content("FOR → GRU")
    end

    it "renders status with cached badge and count" do
      render_inline(described_class.new(search_id: "abc", cached_offer_ids: [offer.id]))
      expect(page).to have_content(I18n.t("searches.providers.duffel.success", count: 1))
      expect(page).to have_content(I18n.t("searches.cached_badge"))
    end
  end
end
