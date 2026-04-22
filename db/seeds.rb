if Airport.count.zero?
  Rails.logger.info("Seeding airports from OurAirports...")
  count = Airport::Import::OurAirports.call
  Rails.logger.info("Imported #{count} airports.")
end

if User.count.zero?
  email = ENV.fetch("OWNER_EMAIL")
  password = ENV.fetch("OWNER_PASSWORD")
  User.create!(email: email, password: password)
  Rails.logger.info("Created owner user #{email}.")
end
