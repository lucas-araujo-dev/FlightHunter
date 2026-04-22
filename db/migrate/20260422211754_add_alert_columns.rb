class AddAlertColumns < ActiveRecord::Migration[8.1]
  def change
    change_table :alerts, bulk: true do |t|
      t.string :origin_type, null: false
      t.string :origin_code, null: false
      t.string :destination_type, null: false
      t.string :destination_code, null: false
      t.string :trip_type, null: false
      t.date :departure_date_from, null: false
      t.date :departure_date_to, null: false
      t.date :return_date_from
      t.date :return_date_to
      t.string :cabin_class, null: false, default: "economy"
      t.integer :passengers, null: false, default: 1
      t.bigint :max_price_cents
      t.integer :max_miles
      t.string :currency, limit: 3, null: false, default: "BRL"
      t.boolean :active, null: false, default: true
      t.datetime :last_checked_at
    end

    add_index :alerts, [:active, :last_checked_at], name: "idx_alerts_active_checked"
  end
end
