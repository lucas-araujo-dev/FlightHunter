class Airport < ApplicationRecord
  validates :name, presence: true
  validates :country, presence: true, length: {is: 2}
  validates :iata_code, uniqueness: true, length: {is: 3}, allow_nil: true
  validates :icao_code, length: {is: 4}, allow_nil: true

  scope :with_iata, -> { where.not(iata_code: nil) }
  scope :in_city, ->(city, country:) { where(city: city, country: country) }
end
