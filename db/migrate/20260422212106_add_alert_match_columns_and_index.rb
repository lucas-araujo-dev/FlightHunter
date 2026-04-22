class AddAlertMatchColumnsAndIndex < ActiveRecord::Migration[8.1]
  def change
    add_column :alert_matches, :notified_at, :datetime
    add_index :alert_matches, [:alert_id, :flight_offer_id], unique: true, name: "idx_alert_matches_unique"
  end
end
