class User < ApplicationRecord
  has_secure_password

  encrypts :program_credentials, deterministic: false

  has_many :alerts, dependent: :destroy

  validates :email, presence: true, uniqueness: {case_sensitive: false}

  def program_credentials
    raw = read_attribute(:program_credentials)
    raw.present? ? JSON.parse(raw) : {}
  end

  def program_credentials=(hash)
    write_attribute(:program_credentials, hash.is_a?(String) ? hash : hash.to_json)
  end
end
