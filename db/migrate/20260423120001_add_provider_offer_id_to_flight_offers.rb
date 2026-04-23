class AddProviderOfferIdToFlightOffers < ActiveRecord::Migration[8.1]
  def change
    add_column :flight_offers, :provider_offer_id, :string
    change_column_null :flight_offers, :provider_offer_id, false
    add_index :flight_offers, [:provider, :provider_offer_id],
      unique: true, name: "idx_flight_offers_provider_offer_unique"
  end
end
