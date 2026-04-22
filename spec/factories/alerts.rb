FactoryBot.define do
  factory :alert do
    user
    origin_type { "airport" }
    origin_code { "FOR" }
    destination_type { "airport" }
    destination_code { "GRU" }
    trip_type { "one_way" }
    departure_date_from { 30.days.from_now.to_date }
    departure_date_to { 45.days.from_now.to_date }
    cabin_class { "economy" }
    passengers { 1 }
    max_price_cents { 80_000 }
    currency { "BRL" }
    active { true }

    trait :round_trip do
      trip_type { "round_trip" }
      return_date_from { 50.days.from_now.to_date }
      return_date_to { 65.days.from_now.to_date }
    end

    trait :miles_only do
      max_price_cents { nil }
      max_miles { 40_000 }
    end

    trait :paused do
      active { false }
    end
  end
end
