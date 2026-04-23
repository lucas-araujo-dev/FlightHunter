class FlightOffer::Search::Base
  TIMEOUT_SECONDS = 15

  def self.call(query) = new(query).call

  def initialize(query)
    @query = query
  end

  def call
    raise NotImplementedError
  end

  def provider_name
    raise NotImplementedError
  end

  protected

  def timed
    start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    yield.tap { @duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start) * 1000).round }
  end

  def log_check(status:, offers_count: 0, error_message: nil)
    ProviderCheck.create!(
      provider: provider_name,
      origin_code: @query.origin_code,
      destination_code: @query.destination_code,
      status: status,
      error_message: error_message&.truncate(1000),
      offers_count: offers_count,
      duration_ms: @duration_ms || 0,
      ran_at: Time.current
    )
  end

  def build_result(status:, offer_ids: [], error_message: nil)
    FlightOffer::Search::Result.new(
      status: status,
      offer_ids: offer_ids,
      duration_ms: @duration_ms || 0,
      error_message: error_message,
      provider: provider_name
    )
  end
end
