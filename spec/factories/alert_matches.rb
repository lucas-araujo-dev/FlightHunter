FactoryBot.define do
  factory :alert_match do
    alert
    flight_offer

    trait :notified do
      notified_at { Time.current }
    end
  end
end
