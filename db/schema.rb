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

ActiveRecord::Schema[7.1].define(version: 2025_04_15_190133) do
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
    t.bigint "news_source_id", null: false
    t.index ["news_source_id"], name: "index_articles_on_news_source_id"
    t.index ["publish_date"], name: "index_articles_on_publish_date"
    t.index ["source"], name: "index_articles_on_source"
    t.index ["topic"], name: "index_articles_on_topic"
  end

  create_table "email_metrics", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "email_type"
    t.string "status"
    t.string "subject"
    t.datetime "sent_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_email_metrics_on_user_id"
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

  create_table "news_sources", force: :cascade do |t|
    t.string "name", null: false
    t.string "url"
    t.string "format", null: false
    t.boolean "active", default: true
    t.jsonb "settings", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "last_fetched_at"
    t.string "last_fetch_status"
    t.integer "last_fetch_article_count"
    t.text "last_fetch_errors"
    t.index ["active"], name: "index_news_sources_on_active"
    t.index ["format"], name: "index_news_sources_on_format"
    t.index ["name"], name: "index_news_sources_on_name", unique: true
  end

  create_table "preferences", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "email_frequency", default: "daily"
    t.boolean "dark_mode", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "sources"
    t.index ["user_id"], name: "index_preferences_on_user_id"
  end

  create_table "topics", force: :cascade do |t|
    t.string "name", null: false
    t.boolean "active", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_topics_on_name", unique: true
  end

  create_table "user_news_sources", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "news_source_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["news_source_id"], name: "index_user_news_sources_on_news_source_id"
    t.index ["user_id", "news_source_id"], name: "index_user_news_sources_on_user_id_and_news_source_id", unique: true
    t.index ["user_id"], name: "index_user_news_sources_on_user_id"
  end

  create_table "user_topics", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "topic_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["topic_id"], name: "index_user_topics_on_topic_id"
    t.index ["user_id", "topic_id"], name: "index_user_topics_on_user_id_and_topic_id", unique: true
    t.index ["user_id"], name: "index_user_topics_on_user_id"
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
    t.boolean "admin"
    t.index ["confirmation_token"], name: "index_users_on_confirmation_token", unique: true
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["is_subscribed"], name: "index_users_on_is_subscribed"
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "articles", "news_sources"
  add_foreign_key "email_metrics", "users"
  add_foreign_key "email_trackings", "users"
  add_foreign_key "preferences", "users"
  add_foreign_key "user_news_sources", "news_sources"
  add_foreign_key "user_news_sources", "users"
  add_foreign_key "user_topics", "topics"
  add_foreign_key "user_topics", "users"
end
