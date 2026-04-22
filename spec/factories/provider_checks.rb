FactoryBot.define do
  factory :provider_check do
    provider { "duffel" }
    origin_code { "FOR" }
    destination_code { "GRU" }
    status { "success" }
    offers_count { 5 }
    duration_ms { 1234 }
    ran_at { Time.current }

    trait :failed do
      status { "failure" }
      error_message { "Timeout" }
      offers_count { 0 }
    end

    trait :rate_limited do
      status { "rate_limited" }
      offers_count { 0 }
    end
  end
end
