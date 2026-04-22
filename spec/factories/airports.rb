FactoryBot.define do
  factory :airport do
    sequence(:iata_code) { |n| ("A".ord + (n % 26)).chr + ("A".ord + ((n / 26) % 26)).chr + ("A".ord + ((n / 676) % 26)).chr }
    sequence(:icao_code) { |n| "Z" + ("A".ord + (n % 26)).chr + ("A".ord + ((n / 26) % 26)).chr + ("A".ord + ((n / 676) % 26)).chr }
    name { "#{city} International Airport" }
    city { "Fortaleza" }
    country { "BR" }
    latitude { -3.7762 }
    longitude { -38.5326 }
    timezone { "America/Fortaleza" }
    airport_type { "large_airport" }

    trait :small do
      airport_type { "small_airport" }
    end

    trait :sao_paulo do
      city { "São Paulo" }
      country { "BR" }
      iata_code { "GRU" }
      icao_code { "SBGR" }
      name { "Guarulhos International" }
    end
  end
end
