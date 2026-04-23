class FlightOffer::Search::Dispatch
  CACHE_TTL_SUCCESS = 30.minutes
  CACHE_TTL_EMPTY = 5.minutes
  PROVIDERS = %w[duffel].freeze

  Result = Data.define(:status, :offer_ids)

  def self.call(query:, search_id:) = new(query: query, search_id: search_id).call

  def initialize(query:, search_id:)
    @query = query
    @search_id = search_id
  end

  def call
    cached = Rails.cache.read(@query.cache_key)
    return Result.new(status: :cache_hit, offer_ids: cached) unless cached.nil?

    enqueue_providers
    Result.new(status: :enqueued, offer_ids: nil)
  end

  private

  def enqueue_providers
    FlightOffer::Search::DuffelJob.perform_later(@query.to_h.transform_keys(&:to_s), @search_id)
  end
end
