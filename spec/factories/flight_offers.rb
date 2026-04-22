FactoryBot.define do
  factory :flight_offer do
    provider { "duffel" }
    offer_type { "cash" }
    association :origin_airport, factory: :airport
    association :destination_airport, factory: :airport
    departure_at { 30.days.from_now.change(hour: 10) }
    arrival_at { 30.days.from_now.change(hour: 13) }
    airline_iata { "AD" }
    flight_numbers { ["AD2716"].to_json }
    stops { 0 }
    cabin_class { "economy" }
    price_cents { 50_000 }
    currency { "BRL" }
    deep_link { "https://example.com/offer/abc" }
    raw_payload { {test: true}.to_json }
    found_at { Time.current }
    expires_at { 24.hours.from_now }

    trait :award do
      offer_type { "award" }
      price_cents { nil }
      currency { nil }
      miles { 35_000 }
      taxes_cents { 15_000 }
      program { "smiles" }
      provider { "smiles" }
    end

    trait :round_trip do
      return_departure_at { 37.days.from_now.change(hour: 18) }
      return_arrival_at { 37.days.from_now.change(hour: 21) }
    end
  end
end
