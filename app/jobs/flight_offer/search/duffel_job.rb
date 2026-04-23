class FlightOffer::Search::DuffelJob < ApplicationJob
  queue_as :flight_offers

  def perform(query_hash, search_id)
    query = FlightOffer::Search::Query.new(**query_hash.symbolize_keys)
    result = FlightOffer::Search::Duffel.call(query)

    FlightOffer::Search::Broadcast.call(
      search_id: search_id,
      provider: :duffel,
      result: result
    )

    cache_ttl = result.empty? ? FlightOffer::Search::Dispatch::CACHE_TTL_EMPTY : FlightOffer::Search::Dispatch::CACHE_TTL_SUCCESS
    Rails.cache.write(query.cache_key, result.offer_ids, expires_in: cache_ttl)
  end
end
