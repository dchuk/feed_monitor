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

ActiveRecord::Schema[8.0].define(version: 2025_10_14_172525) do
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
    t.string "guid", null: false
    t.string "content_fingerprint"
    t.string "title"
    t.string "url", null: false
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
    t.datetime "deleted_at"
    t.index ["content_fingerprint"], name: "index_feed_monitor_items_on_content_fingerprint"
    t.index ["deleted_at"], name: "index_feed_monitor_items_on_deleted_at"
    t.index ["guid"], name: "index_feed_monitor_items_on_guid"
    t.index ["published_at"], name: "index_feed_monitor_items_on_published_at"
    t.index ["scrape_status"], name: "index_feed_monitor_items_on_scrape_status"
    t.index ["source_id", "content_fingerprint"], name: "index_feed_monitor_items_on_source_id_and_content_fingerprint", unique: true
    t.index ["source_id", "created_at"], name: "index_items_on_source_and_created_at_for_rates"
    t.index ["source_id", "guid"], name: "index_feed_monitor_items_on_source_id_and_guid", unique: true
    t.index ["source_id", "published_at", "created_at"], name: "index_feed_monitor_items_on_source_and_published_at"
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
    t.index ["started_at"], name: "index_feed_monitor_scrape_logs_on_started_at"
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
    t.boolean "adaptive_fetching_enabled", default: true, null: false
    t.string "type"
    t.string "fetch_status", default: "idle", null: false
    t.datetime "last_fetch_started_at"
    t.integer "fetch_retry_attempt", default: 0, null: false
    t.datetime "fetch_circuit_opened_at"
    t.datetime "fetch_circuit_until"
    t.decimal "rolling_success_rate", precision: 5, scale: 4
    t.string "health_status", default: "healthy", null: false
    t.datetime "health_status_changed_at"
    t.datetime "auto_paused_at"
    t.datetime "auto_paused_until"
    t.decimal "health_auto_pause_threshold", precision: 5, scale: 4
    t.index ["active", "next_fetch_at"], name: "index_sources_on_active_and_next_fetch", where: "(active = true)"
    t.index ["active"], name: "index_feed_monitor_sources_on_active"
    t.index ["auto_paused_until"], name: "index_feed_monitor_sources_on_auto_paused_until"
    t.index ["created_at"], name: "index_feed_monitor_sources_on_created_at"
    t.index ["failure_count"], name: "index_sources_on_failures", where: "(failure_count > 0)"
    t.index ["feed_url"], name: "index_feed_monitor_sources_on_feed_url", unique: true
    t.index ["fetch_circuit_until"], name: "index_feed_monitor_sources_on_fetch_circuit_until"
    t.index ["fetch_retry_attempt"], name: "index_feed_monitor_sources_on_fetch_retry_attempt"
    t.index ["fetch_status"], name: "index_feed_monitor_sources_on_fetch_status"
    t.index ["health_status"], name: "index_feed_monitor_sources_on_health_status"
    t.index ["next_fetch_at"], name: "index_feed_monitor_sources_on_next_fetch_at"
    t.index ["type"], name: "index_feed_monitor_sources_on_type"
    t.check_constraint "fetch_status::text = ANY (ARRAY['idle'::character varying, 'queued'::character varying, 'fetching'::character varying, 'failed'::character varying]::text[])", name: "check_fetch_status_values"
  end

  create_table "solid_cable_messages", force: :cascade do |t|
    t.binary "channel", null: false
    t.binary "payload", null: false
    t.datetime "created_at", null: false
    t.bigint "channel_hash", null: false
    t.index ["channel"], name: "index_solid_cable_messages_on_channel"
    t.index ["channel_hash"], name: "index_solid_cable_messages_on_channel_hash"
    t.index ["created_at"], name: "index_solid_cable_messages_on_created_at"
  end

  create_table "solid_queue_blocked_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "queue_name", null: false
    t.integer "priority", default: 0, null: false
    t.string "concurrency_key", null: false
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.index ["concurrency_key", "priority", "job_id"], name: "index_solid_queue_blocked_executions_for_release"
    t.index ["expires_at", "concurrency_key"], name: "index_solid_queue_blocked_executions_for_maintenance"
    t.index ["job_id"], name: "index_solid_queue_blocked_executions_on_job_id", unique: true
  end

  create_table "solid_queue_claimed_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.bigint "process_id"
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_claimed_executions_on_job_id", unique: true
    t.index ["process_id", "job_id"], name: "index_solid_queue_claimed_executions_on_process_id_and_job_id"
  end

  create_table "solid_queue_failed_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.text "error"
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_failed_executions_on_job_id", unique: true
  end

  create_table "solid_queue_jobs", force: :cascade do |t|
    t.string "queue_name", null: false
    t.string "class_name", null: false
    t.text "arguments"
    t.integer "priority", default: 0, null: false
    t.string "active_job_id"
    t.datetime "scheduled_at"
    t.datetime "finished_at"
    t.string "concurrency_key"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active_job_id"], name: "index_solid_queue_jobs_on_active_job_id"
    t.index ["class_name"], name: "index_solid_queue_jobs_on_class_name"
    t.index ["finished_at"], name: "index_solid_queue_jobs_on_finished_at"
    t.index ["queue_name", "finished_at"], name: "index_solid_queue_jobs_for_filtering"
    t.index ["scheduled_at", "finished_at"], name: "index_solid_queue_jobs_for_alerting"
  end

  create_table "solid_queue_pauses", force: :cascade do |t|
    t.string "queue_name", null: false
    t.datetime "created_at", null: false
    t.index ["queue_name"], name: "index_solid_queue_pauses_on_queue_name", unique: true
  end

  create_table "solid_queue_processes", force: :cascade do |t|
    t.string "kind", null: false
    t.datetime "last_heartbeat_at", null: false
    t.bigint "supervisor_id"
    t.integer "pid", null: false
    t.string "hostname"
    t.text "metadata"
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.index ["last_heartbeat_at"], name: "index_solid_queue_processes_on_last_heartbeat_at"
    t.index ["name", "supervisor_id"], name: "index_solid_queue_processes_on_name_and_supervisor_id", unique: true
    t.index ["supervisor_id"], name: "index_solid_queue_processes_on_supervisor_id"
  end

  create_table "solid_queue_ready_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "queue_name", null: false
    t.integer "priority", default: 0, null: false
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_ready_executions_on_job_id", unique: true
    t.index ["priority", "job_id"], name: "index_solid_queue_poll_all"
    t.index ["queue_name", "priority", "job_id"], name: "index_solid_queue_poll_by_queue"
  end

  create_table "solid_queue_recurring_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "task_key", null: false
    t.datetime "run_at", null: false
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_recurring_executions_on_job_id", unique: true
    t.index ["task_key", "run_at"], name: "index_solid_queue_recurring_executions_on_task_key_and_run_at", unique: true
  end

  create_table "solid_queue_recurring_tasks", force: :cascade do |t|
    t.string "key", null: false
    t.string "schedule", null: false
    t.string "command", limit: 2048
    t.string "class_name"
    t.text "arguments"
    t.string "queue_name"
    t.integer "priority", default: 0
    t.boolean "static", default: true, null: false
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_solid_queue_recurring_tasks_on_key", unique: true
    t.index ["static"], name: "index_solid_queue_recurring_tasks_on_static"
  end

  create_table "solid_queue_scheduled_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "queue_name", null: false
    t.integer "priority", default: 0, null: false
    t.datetime "scheduled_at", null: false
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_scheduled_executions_on_job_id", unique: true
    t.index ["scheduled_at", "priority", "job_id"], name: "index_solid_queue_dispatch_all"
  end

  create_table "solid_queue_semaphores", force: :cascade do |t|
    t.string "key", null: false
    t.integer "value", default: 1, null: false
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["expires_at"], name: "index_solid_queue_semaphores_on_expires_at"
    t.index ["key", "value"], name: "index_solid_queue_semaphores_on_key_and_value"
    t.index ["key"], name: "index_solid_queue_semaphores_on_key", unique: true
  end

  add_foreign_key "feed_monitor_fetch_logs", "feed_monitor_sources", column: "source_id"
  add_foreign_key "feed_monitor_item_contents", "feed_monitor_items", column: "item_id"
  add_foreign_key "feed_monitor_items", "feed_monitor_sources", column: "source_id"
  add_foreign_key "feed_monitor_scrape_logs", "feed_monitor_items", column: "item_id"
  add_foreign_key "feed_monitor_scrape_logs", "feed_monitor_sources", column: "source_id"
  add_foreign_key "solid_queue_blocked_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_claimed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_failed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_ready_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_recurring_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_scheduled_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
end
