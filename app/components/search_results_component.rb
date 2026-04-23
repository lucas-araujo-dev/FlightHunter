class SearchResultsComponent < ViewComponent::Base
  PROVIDERS = FlightOffer::Search::Dispatch::PROVIDERS

  def initialize(search_id:, cached_offer_ids: nil)
    @search_id = search_id
    @cached_offer_ids = cached_offer_ids
  end

  attr_reader :search_id

  def cached?
    @cached_offer_ids.present?
  end

  def cached_count
    @cached_offer_ids.to_a.size
  end

  def cached_offers
    @cached_offers ||= FlightOffer.where(id: @cached_offer_ids)
      .includes(:origin_airport, :destination_airport)
  end

  def provider_status_label(provider)
    if cached?
      "#{t("searches.providers.#{provider}.success", count: cached_count)} · #{t("searches.cached_badge")}"
    else
      t("searches.providers.#{provider}.searching")
    end
  end
end
