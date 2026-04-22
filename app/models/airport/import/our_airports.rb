require "net/http"
require "csv"
require "stringio"

class Airport::Import::OurAirports
  DEFAULT_SOURCE_URL = "https://davidmegginson.github.io/ourairports-data/airports.csv"
  EXCLUDED_TYPES = %w[heliport closed seaplane_base balloonport].freeze

  def self.source_url
    ENV.fetch("OUR_AIRPORTS_URL", DEFAULT_SOURCE_URL)
  end

  def self.batch_size
    ENV.fetch("OUR_AIRPORTS_BATCH_SIZE", "1000").to_i
  end

  def self.call(source: nil, io: nil)
    new(source: source || source_url, io: io).call
  end

  def initialize(source:, io: nil)
    @source = source
    @io = io
  end

  def call
    csv_io = @io || fetch_remote(@source)
    imported = 0
    batch = []

    CSV.new(csv_io, headers: true).each do |row|
      next if EXCLUDED_TYPES.include?(row["type"])
      next if row["iso_country"].blank?
      next if row["ident"].blank?

      batch << map_row(row)
      if batch.size >= self.class.batch_size
        imported += flush(batch)
        batch = []
      end
    end
    imported += flush(batch) if batch.any?
    imported
  end

  private

  def fetch_remote(source)
    uri = URI.parse(source)
    raise ArgumentError, "Only HTTPS URLs are allowed for remote imports" unless uri.is_a?(URI::HTTPS)

    body = Net::HTTP.get(uri).force_encoding("UTF-8")
    StringIO.new(body)
  end

  def flush(batch)
    now = Time.current
    Airport.upsert_all(
      batch.map { |attrs| attrs.merge(created_at: now, updated_at: now) },
      unique_by: :icao_code
    )
    batch.size
  end

  def map_row(row)
    {
      icao_code: row["ident"].presence,
      iata_code: row["iata_code"].to_s.strip.presence,
      name: row["name"],
      city: row["municipality"].presence,
      country: row["iso_country"],
      latitude: row["latitude_deg"]&.to_f,
      longitude: row["longitude_deg"]&.to_f,
      airport_type: row["type"]
    }
  end
end
