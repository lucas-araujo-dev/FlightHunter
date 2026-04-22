class CreateFlightOffers < ActiveRecord::Migration[8.1]
  def change
    create_table :flight_offers do |t|
      t.string :provider, null: false
      t.string :offer_type, null: false
      t.references :origin_airport, null: false, foreign_key: {to_table: :airports}
      t.references :destination_airport, null: false, foreign_key: {to_table: :airports}
      t.datetime :departure_at, null: false
      t.datetime :arrival_at, null: false
      t.datetime :return_departure_at
      t.datetime :return_arrival_at
      t.string :airline_iata, limit: 3
      t.text :flight_numbers
      t.integer :stops, null: false, default: 0
      t.string :cabin_class
      t.bigint :price_cents
      t.string :currency, limit: 3
      t.integer :miles
      t.bigint :taxes_cents
      t.string :program
      t.text :deep_link, null: false
      t.text :raw_payload
      t.datetime :found_at, null: false
      t.datetime :expires_at
      t.timestamps
    end

    add_index :flight_offers, [:origin_airport_id, :destination_airport_id, :departure_at], name: "idx_flight_offers_route_departure"
    add_index :flight_offers, :provider
    add_index :flight_offers, :found_at
    add_index :flight_offers, :expires_at
  end
end
