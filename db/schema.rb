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

ActiveRecord::Schema[8.1].define(version: 2026_04_22_211059) do
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
  end

  create_table "alerts", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["user_id"], name: "index_alerts_on_user_id"
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

  add_foreign_key "alerts", "users"
end
