class Airport::Autocomplete
  Result = Data.define(:type, :code, :display, :secondary)
  DEFAULT_LIMIT = 10
  DEFAULT_MIN_CITY_AIRPORTS = 2
  MIN_QUERY_LENGTH = 2

  def self.call(query, limit: DEFAULT_LIMIT, min_city_airports: DEFAULT_MIN_CITY_AIRPORTS)
    new(query, limit: limit, min_city_airports: min_city_airports).call
  end

  def initialize(query, limit:, min_city_airports:)
    @query = query.to_s.strip.downcase
    @limit = limit
    @min_city_airports = min_city_airports
  end

  def call
    return [] if @query.length < MIN_QUERY_LENGTH

    matches = candidate_airports
    aggregate(matches).first(@limit)
  end

  private

  def candidate_airports
    prefix = "#{@query}%"
    substring = "%#{@query}%"
    escaped = @query.gsub("'", "''")

    Airport
      .where(
        "lower(iata_code) LIKE ? OR lower(icao_code) LIKE ? OR lower(name) LIKE ? OR lower(city) LIKE ?",
        prefix, prefix, substring, substring
      )
      .order(Arel.sql(<<~SQL))
        CASE
          WHEN lower(iata_code) LIKE '#{escaped}%' THEN 100
          WHEN lower(icao_code) LIKE '#{escaped}%' THEN 80
          WHEN lower(city) LIKE '#{escaped}%' THEN 60
          ELSE 50
        END DESC,
        CASE WHEN iata_code IS NOT NULL THEN 0 ELSE 1 END,
        name ASC
      SQL
      .limit(@limit * 3)
      .to_a
  end

  def aggregate(airports)
    grouped = airports.group_by { |a| [a.city, a.country] }
    results = []

    grouped.each do |(city, country), list|
      if city.present? && list.size >= @min_city_airports
        results << Result.new(
          type: "city",
          code: "#{city}|#{country}",
          display: "#{city} (#{list.size} airports)",
          secondary: country
        )
      else
        list.each do |airport|
          next if airport.iata_code.blank?
          results << Result.new(
            type: "airport",
            code: airport.iata_code,
            display: "#{airport.iata_code} — #{airport.name}",
            secondary: [airport.city, airport.country].compact.join(", ")
          )
        end
      end
    end

    results
  end
end
