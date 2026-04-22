class CreateProviderChecks < ActiveRecord::Migration[8.1]
  def change
    create_table :provider_checks do |t|
      t.string :provider, null: false
      t.string :origin_code
      t.string :destination_code
      t.string :status, null: false
      t.text :error_message
      t.integer :offers_count, null: false, default: 0
      t.integer :duration_ms
      t.datetime :ran_at, null: false
      t.timestamps
    end

    add_index :provider_checks, [:provider, :ran_at]
    add_index :provider_checks, :status
  end
end
