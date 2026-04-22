class AlertMatch < ApplicationRecord
  belongs_to :alert
  belongs_to :flight_offer
end
