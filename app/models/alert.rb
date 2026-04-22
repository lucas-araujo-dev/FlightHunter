class Alert < ApplicationRecord
  ORIGIN_TYPES = %w[airport city].freeze
  TRIP_TYPES = %w[one_way round_trip].freeze
  CABIN_CLASSES = %w[economy premium_economy business first].freeze
  MAX_ACTIVE_PER_USER = 10

  enum :origin_type, ORIGIN_TYPES.index_with(&:itself), prefix: :origin
  enum :destination_type, ORIGIN_TYPES.index_with(&:itself), prefix: :destination
  enum :trip_type, TRIP_TYPES.index_with(&:itself)
  enum :cabin_class, CABIN_CLASSES.index_with(&:itself), prefix: :cabin

  belongs_to :user
  has_many :alert_matches, dependent: :destroy
  has_many :flight_offers, through: :alert_matches

  validates :origin_code, :destination_code, presence: true
  validates :departure_date_from, :departure_date_to, presence: true
  validates :passengers, numericality: {greater_than: 0}
  validates :currency, length: {is: 3}
  validate :at_least_one_ceiling
  validate :round_trip_has_return_dates
  validate :departure_range_well_formed
  validate :departure_not_in_past
  validate :respects_active_limit

  scope :active, -> { where(active: true) }
  scope :due_for_check, -> {
    where("last_checked_at IS NULL OR last_checked_at < ?", 2.hours.ago)
  }

  private

  def at_least_one_ceiling
    if max_price_cents.blank? && max_miles.blank?
      errors.add(:base, "defina teto de preço ou milhas")
    end
  end

  def round_trip_has_return_dates
    return unless trip_type == "round_trip"
    if return_date_from.blank? || return_date_to.blank?
      errors.add(:return_date_from, "é obrigatório em round_trip") if return_date_from.blank?
      errors.add(:return_date_to, "é obrigatório em round_trip") if return_date_to.blank?
    end
  end

  def departure_range_well_formed
    return if departure_date_from.blank? || departure_date_to.blank?
    if departure_date_to < departure_date_from
      errors.add(:departure_date_to, "deve ser >= departure_date_from")
    end
  end

  def departure_not_in_past
    return if departure_date_from.blank?
    if departure_date_from < Date.current
      errors.add(:departure_date_from, "não pode ser no passado")
    end
  end

  def respects_active_limit
    return unless active?
    return unless user
    current_active = user.alerts.where(active: true)
    current_active = current_active.where.not(id: id) if persisted?
    if current_active.count >= MAX_ACTIVE_PER_USER
      errors.add(:base, "limite de #{MAX_ACTIVE_PER_USER} alerts ativos atingido")
    end
  end
end
