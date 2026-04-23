require "digest"

class FlightOffer::Search::Query < Data.define(
  :origin_type, :origin_code,
  :destination_type, :destination_code,
  :trip_type,
  :departure_date_from, :departure_date_to,
  :return_date_from, :return_date_to,
  :cabin_class, :passengers
)
  TRIP_TYPES = %w[one_way round_trip].freeze
  LOCATION_TYPES = %w[airport city].freeze
  CABIN_CLASSES = FlightOffer::CABIN_CLASSES

  class InvalidError < StandardError
    attr_reader :i18n_key, :interpolations

    def initialize(i18n_key, **interpolations)
      @i18n_key = i18n_key
      @interpolations = interpolations
      super("Invalid search query: #{i18n_key}")
    end
  end

  def self.from_params(params)
    p = params.respond_to?(:to_unsafe_h) ? params.to_unsafe_h.with_indifferent_access : params.with_indifferent_access
    dep_from = Date.parse(p[:departure_date_from].to_s)
    dep_to = Date.parse((p[:departure_date_to].presence || p[:departure_date_from]).to_s)

    new(
      origin_type: p[:origin_type],
      origin_code: p[:origin_code],
      destination_type: p[:destination_type],
      destination_code: p[:destination_code],
      trip_type: p[:trip_type].presence || "one_way",
      departure_date_from: dep_from,
      departure_date_to: dep_to,
      return_date_from: p[:return_date_from].presence && Date.parse(p[:return_date_from]),
      return_date_to: p[:return_date_to].presence && Date.parse(p[:return_date_to]),
      cabin_class: p[:cabin_class].presence || "economy",
      passengers: (p[:passengers].presence || 1).to_i
    )
  end

  def round_trip? = trip_type == "round_trip"

  def one_way? = trip_type == "one_way"

  def origin_airports
    resolve_airports(origin_type, origin_code)
  end

  def destination_airports
    resolve_airports(destination_type, destination_code)
  end

  def cache_key
    payload = {
      origin_type: origin_type, origin_code: origin_code,
      destination_type: destination_type, destination_code: destination_code,
      trip_type: trip_type,
      dep_from: departure_date_from.iso8601,
      dep_to: departure_date_to.iso8601,
      return_from: return_date_from&.iso8601,
      return_to: return_date_to&.iso8601,
      cabin_class: cabin_class, passengers: passengers
    }.sort.to_h
    "flight_offer:search:#{Digest::SHA1.hexdigest(payload.to_json)}"
  end

  def validate!
    raise InvalidError.new("searches.errors.invalid_origin_type") unless LOCATION_TYPES.include?(origin_type)
    raise InvalidError.new("searches.errors.invalid_destination_type") unless LOCATION_TYPES.include?(destination_type)
    raise InvalidError.new("searches.errors.invalid_trip_type") unless TRIP_TYPES.include?(trip_type)
    raise InvalidError.new("searches.errors.invalid_cabin_class") unless CABIN_CLASSES.include?(cabin_class)
    raise InvalidError.new("searches.errors.invalid_passengers") unless (1..9).cover?(passengers)
    raise InvalidError.new("searches.errors.departure_range_invalid") if departure_date_from > departure_date_to
    raise InvalidError.new("searches.errors.departure_in_past") if departure_date_from < Date.current
    if round_trip?
      raise InvalidError.new("searches.errors.return_date_required") if return_date_from.blank?
      raise InvalidError.new("searches.errors.return_before_departure") if return_date_from < departure_date_from
    end
    raise InvalidError.new("searches.errors.origin_has_no_airports") if origin_airports.empty?
    raise InvalidError.new("searches.errors.destination_has_no_airports") if destination_airports.empty?
    self
  end

  private

  def resolve_airports(type, code)
    case type
    when "airport" then Airport.where(iata_code: code).to_a
    when "city"
      city, country = code.to_s.split("|", 2)
      Airport.where(city: city, country: country).to_a
    else []
    end
  end
end
