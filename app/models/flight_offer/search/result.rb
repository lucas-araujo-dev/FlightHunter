class FlightOffer::Search::Result < Data.define(:status, :offer_ids, :duration_ms, :error_message, :provider)
  STATUSES = %w[success empty failure timeout cached].freeze

  def success? = status == "success"

  def empty? = status == "empty"

  def cached? = status == "cached"

  def failed? = %w[failure timeout].include?(status)
end
