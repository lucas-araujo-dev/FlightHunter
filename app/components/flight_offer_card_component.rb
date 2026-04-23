class FlightOfferCardComponent < ViewComponent::Base
  def initialize(offer:, provider: nil)
    @offer = offer
    @provider_override = provider
  end

  def provider_label
    (@provider_override || @offer.provider).to_s
  end

  def price_display
    return nil unless @offer.price_cents
    helpers.number_to_currency(@offer.price_cents / 100.0, unit: @offer.currency || "BRL")
  end

  def stops_label
    @offer.stops.zero? ? t("flight_offer.direct") : t("flight_offer.stops", count: @offer.stops)
  end

  def departure_display
    I18n.l(@offer.departure_at, format: :short)
  end
end
