class AlertMatch < ApplicationRecord
  belongs_to :alert
  belongs_to :flight_offer

  validates :alert_id, uniqueness: {scope: :flight_offer_id}

  scope :pending, -> { where(notified_at: nil) }
  scope :notified, -> { where.not(notified_at: nil) }

  def notified?
    notified_at.present?
  end
end
