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

ActiveRecord::Schema[8.0].define(version: 2024_10_08_120000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "feed_monitor_sources", force: :cascade do |t|
    t.string "name", null: false
    t.string "feed_url", null: false
    t.string "website_url"
    t.boolean "active", default: true, null: false
    t.string "feed_format"
    t.integer "fetch_interval_hours", default: 6, null: false
    t.datetime "next_fetch_at"
    t.datetime "last_fetched_at"
    t.integer "last_fetch_duration_ms"
    t.integer "last_http_status"
    t.text "last_error"
    t.datetime "last_error_at"
    t.string "etag"
    t.datetime "last_modified"
    t.integer "failure_count", default: 0, null: false
    t.datetime "backoff_until"
    t.integer "items_count", default: 0, null: false
    t.boolean "scraping_enabled", default: false, null: false
    t.boolean "auto_scrape", default: false, null: false
    t.jsonb "scrape_settings", default: {}, null: false
    t.string "scraper_adapter", default: "readability", null: false
    t.boolean "requires_javascript", default: false, null: false
    t.jsonb "custom_headers", default: {}, null: false
    t.integer "items_retention_days"
    t.integer "max_items"
    t.jsonb "metadata", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active"], name: "index_feed_monitor_sources_on_active"
    t.index ["feed_url"], name: "index_feed_monitor_sources_on_feed_url", unique: true
    t.index ["next_fetch_at"], name: "index_feed_monitor_sources_on_next_fetch_at"
  end
end
