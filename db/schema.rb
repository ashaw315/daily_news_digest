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

ActiveRecord::Schema[7.1].define(version: 2025_03_21_184248) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "apis", force: :cascade do |t|
    t.string "name", null: false
    t.string "endpoint", null: false
    t.integer "priority", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_apis_on_name", unique: true
    t.index ["priority"], name: "index_apis_on_priority"
  end

  create_table "articles", force: :cascade do |t|
    t.string "title", null: false
    t.text "summary"
    t.string "url", null: false
    t.datetime "publish_date"
    t.string "source"
    t.string "topic"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["publish_date"], name: "index_articles_on_publish_date"
    t.index ["source"], name: "index_articles_on_source"
    t.index ["topic"], name: "index_articles_on_topic"
  end

  create_table "email_trackings", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.integer "open_count", default: 0
    t.integer "click_count", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id", "created_at"], name: "index_email_trackings_on_user_id_and_created_at"
    t.index ["user_id"], name: "index_email_trackings_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "confirmation_token"
    t.datetime "confirmed_at"
    t.datetime "confirmation_sent_at"
    t.string "unconfirmed_email"
    t.jsonb "preferences", default: {}, null: false
    t.boolean "is_subscribed", default: false, null: false
    t.string "name"
    t.string "unsubscribe_token"
    t.index ["confirmation_token"], name: "index_users_on_confirmation_token", unique: true
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["is_subscribed"], name: "index_users_on_is_subscribed"
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "email_trackings", "users"
end
