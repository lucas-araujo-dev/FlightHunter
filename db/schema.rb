# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_04_22_213733) do
  create_table "airports", force: :cascade do |t|
    t.string "airport_type"
    t.string "city"
    t.string "country", limit: 2, null: false
    t.datetime "created_at", null: false
    t.string "iata_code", limit: 3
    t.string "icao_code", limit: 4
    t.float "latitude"
    t.float "longitude"
    t.string "name", null: false
    t.string "timezone"
    t.datetime "updated_at", null: false
    t.index ["city"], name: "index_airports_on_city"
    t.index ["country"], name: "index_airports_on_country"
    t.index ["iata_code"], name: "index_airports_on_iata_code", unique: true, where: "iata_code IS NOT NULL"
    t.index ["icao_code"], name: "index_airports_on_icao_code", unique: true, where: "icao_code IS NOT NULL"
  end

  create_table "alert_matches", force: :cascade do |t|
    t.integer "alert_id", null: false
    t.datetime "created_at", null: false
    t.integer "flight_offer_id", null: false
    t.datetime "notified_at"
    t.datetime "updated_at", null: false
    t.index ["alert_id", "flight_offer_id"], name: "idx_alert_matches_unique", unique: true
    t.index ["alert_id"], name: "index_alert_matches_on_alert_id"
    t.index ["flight_offer_id"], name: "index_alert_matches_on_flight_offer_id"
  end

  create_table "alerts", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.string "cabin_class", default: "economy", null: false
    t.datetime "created_at", null: false
    t.string "currency", limit: 3, default: "BRL", null: false
    t.date "departure_date_from", null: false
    t.date "departure_date_to", null: false
    t.string "destination_code", null: false
    t.string "destination_type", null: false
    t.datetime "last_checked_at"
    t.integer "max_miles"
    t.bigint "max_price_cents"
    t.string "origin_code", null: false
    t.string "origin_type", null: false
    t.integer "passengers", default: 1, null: false
    t.date "return_date_from"
    t.date "return_date_to"
    t.string "trip_type", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["active", "last_checked_at"], name: "idx_alerts_active_checked"
    t.index ["user_id"], name: "index_alerts_on_user_id"
  end

  create_table "flight_offers", force: :cascade do |t|
    t.string "airline_iata", limit: 3
    t.datetime "arrival_at", null: false
    t.string "cabin_class"
    t.datetime "created_at", null: false
    t.string "currency", limit: 3
    t.text "deep_link", null: false
    t.datetime "departure_at", null: false
    t.integer "destination_airport_id", null: false
    t.datetime "expires_at"
    t.text "flight_numbers"
    t.datetime "found_at", null: false
    t.integer "miles"
    t.string "offer_type", null: false
    t.integer "origin_airport_id", null: false
    t.bigint "price_cents"
    t.string "program"
    t.string "provider", null: false
    t.text "raw_payload"
    t.datetime "return_arrival_at"
    t.datetime "return_departure_at"
    t.integer "stops", default: 0, null: false
    t.bigint "taxes_cents"
    t.datetime "updated_at", null: false
    t.index ["destination_airport_id"], name: "index_flight_offers_on_destination_airport_id"
    t.index ["expires_at"], name: "index_flight_offers_on_expires_at"
    t.index ["found_at"], name: "index_flight_offers_on_found_at"
    t.index ["origin_airport_id", "destination_airport_id", "departure_at"], name: "idx_flight_offers_route_departure"
    t.index ["origin_airport_id"], name: "index_flight_offers_on_origin_airport_id"
    t.index ["provider"], name: "index_flight_offers_on_provider"
  end

  create_table "provider_checks", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "destination_code"
    t.integer "duration_ms"
    t.text "error_message"
    t.integer "offers_count", default: 0, null: false
    t.string "origin_code"
    t.string "provider", null: false
    t.datetime "ran_at", null: false
    t.string "status", null: false
    t.datetime "updated_at", null: false
    t.index ["provider", "ran_at"], name: "index_provider_checks_on_provider_and_ran_at"
    t.index ["status"], name: "index_provider_checks_on_status"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.string "password_digest", null: false
    t.text "program_credentials"
    t.string "telegram_chat_id"
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  add_foreign_key "alert_matches", "alerts"
  add_foreign_key "alert_matches", "flight_offers"
  add_foreign_key "alerts", "users"
  add_foreign_key "flight_offers", "airports", column: "destination_airport_id"
  add_foreign_key "flight_offers", "airports", column: "origin_airport_id"
end
