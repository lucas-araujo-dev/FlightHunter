class CreateAirports < ActiveRecord::Migration[8.1]
  def change
    create_table :airports do |t|
      t.string :iata_code, limit: 3
      t.string :icao_code, limit: 4
      t.string :name, null: false
      t.string :city
      t.string :country, limit: 2, null: false
      t.float :latitude
      t.float :longitude
      t.string :timezone
      t.string :airport_type
      t.timestamps
    end

    add_index :airports, :iata_code, unique: true, where: "iata_code IS NOT NULL"
    add_index :airports, :city
    add_index :airports, :country
  end
end
