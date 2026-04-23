class FlightOffer::Search::Dispatch
  CACHE_TTL_SUCCESS = 30.minutes
  CACHE_TTL_EMPTY = 5.minutes
  PROVIDERS = %w[duffel].freeze

  def self.call(query:, search_id:) = new(query: query, search_id: search_id).call

  def initialize(query:, search_id:)
    @query = query
    @search_id = search_id
  end

  def call
    cached = Rails.cache.read(@query.cache_key)
    return deliver_cached(cached) unless cached.nil?

    enqueue_providers
    :enqueued
  end

  private

  def deliver_cached(offer_ids)
    PROVIDERS.each do |provider|
      FlightOffer::Search::Broadcast.cached(
        search_id: @search_id,
        provider: provider,
        offer_ids: offer_ids
      )
    end
    :cache_hit
  end

  def enqueue_providers
    FlightOffer::Search::DuffelJob.perform_later(@query.to_h.transform_keys(&:to_s), @search_id)
  end
end
