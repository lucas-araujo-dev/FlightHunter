class ProviderCheck < ApplicationRecord
  STATUSES = %w[success failure rate_limited].freeze

  enum :status, STATUSES.index_with(&:itself), prefix: :status

  validates :provider, presence: true
  validates :status, presence: true
  validates :ran_at, presence: true

  scope :recent, -> { order(ran_at: :desc) }
  scope :for_provider, ->(provider) { where(provider: provider) }
  scope :failed, -> { where.not(status: "success") }
end
