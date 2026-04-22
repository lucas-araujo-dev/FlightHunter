class FlightOffer < ApplicationRecord
  PROVIDERS = %w[duffel amadeus seats_aero smiles latam_pass tudoazul].freeze
  OFFER_TYPES = %w[cash award].freeze
  CABIN_CLASSES = %w[economy premium_economy business first].freeze

  enum :provider, PROVIDERS.index_with(&:itself)
  enum :offer_type, OFFER_TYPES.index_with(&:itself)
  enum :cabin_class, CABIN_CLASSES.index_with(&:itself), prefix: :cabin

  belongs_to :origin_airport, class_name: "Airport"
  belongs_to :destination_airport, class_name: "Airport"
  has_many :alert_matches, dependent: :destroy

  validates :provider, :offer_type, presence: true
  validates :deep_link, presence: true
  validates :departure_at, :arrival_at, :found_at, presence: true
  validates :stops, numericality: {greater_than_or_equal_to: 0}

  scope :for_route, ->(origin, destination) {
    where(origin_airport: origin, destination_airport: destination)
  }
  scope :expired, -> { where("expires_at < ?", Time.current) }

  def flight_numbers
    raw = read_attribute(:flight_numbers)
    raw.present? ? JSON.parse(raw) : []
  end

  def flight_numbers=(arr)
    write_attribute(:flight_numbers, arr.is_a?(String) ? arr : arr.to_json)
  end

  def raw_payload
    raw = read_attribute(:raw_payload)
    raw.present? ? JSON.parse(raw) : {}
  end
end
