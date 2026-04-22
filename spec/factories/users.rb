FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "owner#{n}@flighthunter.local" }
    password { "owner-password-123" }
    program_credentials { {} }
  end
end
