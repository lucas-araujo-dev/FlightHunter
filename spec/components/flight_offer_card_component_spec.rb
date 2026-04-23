require "rails_helper"

RSpec.describe FlightOfferCardComponent, type: :component do
  let(:offer) do
    create(:flight_offer,
      origin_airport: create(:airport, iata_code: "FOR", city: "Fortaleza"),
      destination_airport: create(:airport, iata_code: "GRU", city: "São Paulo"),
      airline_iata: "AD", stops: 0, price_cents: 75_000, currency: "BRL",
      deep_link: "https://example.com/o/1")
  end

  it "renders origin and destination IATAs" do
    render_inline(described_class.new(offer: offer))
    expect(page).to have_content("FOR → GRU")
  end

  it "renders provider label in caps" do
    render_inline(described_class.new(offer: offer))
    expect(page).to have_content("DUFFEL")
  end

  it "renders 'direct' when stops is zero" do
    render_inline(described_class.new(offer: offer))
    expect(page).to have_content(I18n.t("flight_offer.direct"))
  end

  it "renders N stops when >0" do
    offer.update!(stops: 2)
    render_inline(described_class.new(offer: offer))
    expect(page).to have_content(I18n.t("flight_offer.stops", count: 2))
  end

  it "respects provider override" do
    render_inline(described_class.new(offer: offer, provider: "amadeus"))
    expect(page).to have_content("AMADEUS")
  end

  it "renders the deep link with rel noopener" do
    render_inline(described_class.new(offer: offer))
    link = page.find("a")
    expect(link[:href]).to eq("https://example.com/o/1")
    expect(link[:rel]).to include("noopener")
  end
end
