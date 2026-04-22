class AddUniqueIndexToAirportsIcaoCode < ActiveRecord::Migration[8.1]
  def change
    add_index :airports, :icao_code, unique: true, where: "icao_code IS NOT NULL"
  end
end
