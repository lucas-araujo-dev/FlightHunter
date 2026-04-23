class ProviderStatusComponentPreview < ViewComponent::Preview
  def success
    render(ProviderStatusComponent.new(provider: "duffel",
      result: FlightOffer::Search::Result.new(
        status: "success", offer_ids: [1, 2, 3],
        duration_ms: 500, error_message: nil, provider: "duffel"
      )))
  end

  def failure
    render(ProviderStatusComponent.new(provider: "duffel",
      result: FlightOffer::Search::Result.new(
        status: "failure", offer_ids: [],
        duration_ms: 500, error_message: "Timeout", provider: "duffel"
      )))
  end

  def cached
    render(ProviderStatusComponent.new(provider: "duffel",
      result: FlightOffer::Search::Result.new(
        status: "cached", offer_ids: [1, 2],
        duration_ms: 0, error_message: nil, provider: "duffel"
      )))
  end
end
