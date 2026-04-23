require "httparty"
require "bigdecimal"

class FlightOffer::Search::Duffel < FlightOffer::Search::Base
  include HTTParty

  BASE_URL = "https://api.duffel.com".freeze
  API_VERSION = "v2".freeze
  DEEP_LINK_BASE = "https://app.duffel.com/offers".freeze
  SUPPLIER_TIMEOUT_MS = 10_000

  def provider_name = "duffel"

  def call
    timed { fetch_and_persist }
  rescue Net::OpenTimeout, Net::ReadTimeout, HTTParty::Error => e
    log_check(status: "failure", error_message: e.message)
    build_result(status: "timeout", error_message: e.message)
  rescue => e
    Sentry.capture_exception(e) if defined?(Sentry)
    log_check(status: "failure", error_message: e.message)
    build_result(status: "failure", error_message: e.message)
  end

  private

  def fetch_and_persist
    response = self.class.post(
      "#{BASE_URL}/air/offer_requests",
      query: {return_offers: true, supplier_timeout: SUPPLIER_TIMEOUT_MS},
      headers: {
        "Authorization" => "Bearer #{api_key}",
        "Duffel-Version" => API_VERSION,
        "Content-Type" => "application/json",
        "Accept" => "application/json"
      },
      body: request_body.to_json,
      timeout: TIMEOUT_SECONDS
    )

    return rate_limited_result if response.code == 429
    raise "Duffel HTTP #{response.code}: #{response.body.to_s[0, 500]}" unless response.success?

    offers = response.parsed_response.dig("data", "offers") || []
    return empty_result if offers.empty?

    records = offers.filter_map { |offer| build_record(offer) }
    return empty_result if records.empty?

    FlightOffer.upsert_all(records, unique_by: :idx_flight_offers_provider_offer_unique)
    offer_ids = FlightOffer.where(
      provider: "duffel",
      provider_offer_id: records.pluck(:provider_offer_id)
    ).pluck(:id)

    log_check(status: "success", offers_count: offer_ids.size)
    build_result(status: "success", offer_ids: offer_ids)
  end

  def rate_limited_result
    log_check(status: "rate_limited", error_message: "HTTP 429")
    build_result(status: "failure", error_message: "Duffel rate limit")
  end

  def empty_result
    log_check(status: "success", offers_count: 0)
    build_result(status: "empty")
  end

  def api_key
    Rails.application.credentials.dig(:duffel, :api_key) ||
      raise("Duffel credentials ausentes (credentials.duffel.api_key)")
  end

  def request_body
    {
      data: {
        slices: slices,
        passengers: Array.new(@query.passengers) { {type: "adult"} },
        cabin_class: @query.cabin_class
      }
    }
  end

  def slices
    origin = @query.origin_airports.first.iata_code
    destination = @query.destination_airports.first.iata_code

    out = [{origin: origin, destination: destination, departure_date: @query.departure_date_from.iso8601}]
    if @query.round_trip?
      out << {origin: destination, destination: origin, departure_date: @query.return_date_from.iso8601}
    end
    out
  end

  def build_record(offer)
    origin_iata = offer.dig("slices", 0, "origin", "iata_code")
    destination_iata = offer.dig("slices", 0, "destination", "iata_code")
    origin_airport = Airport.find_by(iata_code: origin_iata)
    destination_airport = Airport.find_by(iata_code: destination_iata)
    return nil unless origin_airport && destination_airport

    now = Time.current
    first_slice = offer["slices"][0]
    first_segment = first_slice["segments"].first
    last_segment = first_slice["segments"].last
    second_slice = offer["slices"][1]

    {
      provider: "duffel",
      provider_offer_id: offer.fetch("id"),
      offer_type: "cash",
      origin_airport_id: origin_airport.id,
      destination_airport_id: destination_airport.id,
      departure_at: first_segment["departing_at"],
      arrival_at: last_segment["arriving_at"],
      return_departure_at: second_slice&.dig("segments", 0, "departing_at"),
      return_arrival_at: second_slice&.dig("segments", -1, "arriving_at"),
      airline_iata: first_segment.dig("marketing_carrier", "iata_code"),
      flight_numbers: first_slice["segments"]
        .pluck("marketing_carrier_flight_number").compact.to_json,
      stops: first_slice["segments"].length - 1,
      cabin_class: @query.cabin_class,
      price_cents: (BigDecimal(offer["total_amount"]) * 100).to_i,
      currency: offer["total_currency"],
      deep_link: "#{DEEP_LINK_BASE}/#{offer.fetch("id")}",
      raw_payload: offer.to_json,
      found_at: now,
      expires_at: offer["expires_at"],
      created_at: now,
      updated_at: now
    }
  end
end
