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

ActiveRecord::Schema[8.0].define(version: 2025_10_09_103000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "feed_monitor_fetch_logs", force: :cascade do |t|
    t.bigint "source_id", null: false
    t.boolean "success"
    t.integer "items_created", default: 0, null: false
    t.integer "items_updated", default: 0, null: false
    t.integer "items_failed", default: 0, null: false
    t.datetime "started_at", null: false
    t.datetime "completed_at"
    t.integer "duration_ms"
    t.integer "http_status"
    t.jsonb "http_response_headers", default: {}, null: false
    t.string "error_class"
    t.text "error_message"
    t.text "error_backtrace"
    t.integer "feed_size_bytes"
    t.integer "items_in_feed"
    t.string "job_id"
    t.jsonb "metadata", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_feed_monitor_fetch_logs_on_created_at"
    t.index ["job_id"], name: "index_feed_monitor_fetch_logs_on_job_id"
    t.index ["source_id"], name: "index_feed_monitor_fetch_logs_on_source_id"
    t.index ["started_at"], name: "index_feed_monitor_fetch_logs_on_started_at"
    t.index ["success"], name: "index_feed_monitor_fetch_logs_on_success"
  end

  create_table "feed_monitor_item_contents", force: :cascade do |t|
    t.bigint "item_id", null: false
    t.text "scraped_html"
    t.text "scraped_content"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["item_id"], name: "index_feed_monitor_item_contents_on_item_id", unique: true
  end

  create_table "feed_monitor_items", force: :cascade do |t|
    t.bigint "source_id", null: false
    t.string "guid"
    t.string "content_fingerprint"
    t.string "title"
    t.string "url"
    t.string "canonical_url"
    t.string "author"
    t.jsonb "authors", default: [], null: false
    t.text "summary"
    t.text "content"
    t.datetime "scraped_at"
    t.string "scrape_status"
    t.datetime "published_at"
    t.datetime "updated_at_source"
    t.jsonb "categories", default: [], null: false
    t.jsonb "tags", default: [], null: false
    t.jsonb "keywords", default: [], null: false
    t.jsonb "enclosures", default: [], null: false
    t.string "media_thumbnail_url"
    t.jsonb "media_content", default: [], null: false
    t.string "language"
    t.string "copyright"
    t.string "comments_url"
    t.integer "comments_count", default: 0, null: false
    t.jsonb "metadata", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["content_fingerprint"], name: "index_feed_monitor_items_on_content_fingerprint"
    t.index ["guid"], name: "index_feed_monitor_items_on_guid"
    t.index ["published_at"], name: "index_feed_monitor_items_on_published_at"
    t.index ["scrape_status"], name: "index_feed_monitor_items_on_scrape_status"
    t.index ["source_id", "content_fingerprint"], name: "index_feed_monitor_items_on_source_id_and_content_fingerprint", unique: true
    t.index ["source_id", "guid"], name: "index_feed_monitor_items_on_source_id_and_guid", unique: true
    t.index ["source_id"], name: "index_feed_monitor_items_on_source_id"
    t.index ["url"], name: "index_feed_monitor_items_on_url"
  end

  create_table "feed_monitor_scrape_logs", force: :cascade do |t|
    t.bigint "item_id", null: false
    t.bigint "source_id", null: false
    t.boolean "success"
    t.datetime "started_at", null: false
    t.datetime "completed_at"
    t.integer "duration_ms"
    t.integer "http_status"
    t.string "scraper_adapter"
    t.integer "content_length"
    t.string "error_class"
    t.text "error_message"
    t.jsonb "metadata", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_feed_monitor_scrape_logs_on_created_at"
    t.index ["item_id"], name: "index_feed_monitor_scrape_logs_on_item_id"
    t.index ["source_id"], name: "index_feed_monitor_scrape_logs_on_source_id"
    t.index ["success"], name: "index_feed_monitor_scrape_logs_on_success"
  end

  create_table "feed_monitor_sources", force: :cascade do |t|
    t.string "name", null: false
    t.string "feed_url", null: false
    t.string "website_url"
    t.boolean "active", default: true, null: false
    t.string "feed_format"
    t.integer "fetch_interval_minutes", default: 360, null: false
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
    t.boolean "feed_content_readability_enabled", default: false, null: false
    t.index ["active"], name: "index_feed_monitor_sources_on_active"
    t.index ["feed_url"], name: "index_feed_monitor_sources_on_feed_url", unique: true
    t.index ["next_fetch_at"], name: "index_feed_monitor_sources_on_next_fetch_at"
  end

  add_foreign_key "feed_monitor_fetch_logs", "feed_monitor_sources", column: "source_id"
  add_foreign_key "feed_monitor_item_contents", "feed_monitor_items", column: "item_id"
  add_foreign_key "feed_monitor_items", "feed_monitor_sources", column: "source_id"
  add_foreign_key "feed_monitor_scrape_logs", "feed_monitor_items", column: "item_id"
  add_foreign_key "feed_monitor_scrape_logs", "feed_monitor_sources", column: "source_id"
end
