class FlightOfferCardComponentPreview < ViewComponent::Preview
  def default
    offer = FlightOffer.first || build_dummy_offer
    render(FlightOfferCardComponent.new(offer: offer))
  end

  def with_stops
    offer = build_dummy_offer(stops: 2)
    render(FlightOfferCardComponent.new(offer: offer))
  end

  private

  def build_dummy_offer(stops: 0)
    FlightOffer.new(
      provider: "duffel", offer_type: "cash",
      origin_airport: Airport.new(iata_code: "FOR"),
      destination_airport: Airport.new(iata_code: "GRU"),
      departure_at: 10.days.from_now,
      arrival_at: 10.days.from_now + 3.hours,
      airline_iata: "AD", stops: stops,
      price_cents: 85_000, currency: "BRL",
      deep_link: "https://example.com"
    )
  end
end
