# frozen_string_literal: true

class CreateSourceMonitorSources < ActiveRecord::Migration[8.0]
  def change
    create_table :sourcemon_sources do |t|
      t.string :name, null: false
      t.string :feed_url, null: false
      t.string :website_url
      t.boolean :active, null: false, default: true
      t.string :feed_format
      t.integer :fetch_interval_hours, null: false, default: 6
      t.datetime :next_fetch_at
      t.datetime :last_fetched_at
      t.integer :last_fetch_duration_ms
      t.integer :last_http_status
      t.text :last_error
      t.datetime :last_error_at
      t.string :etag
      t.datetime :last_modified
      t.integer :failure_count, null: false, default: 0
      t.datetime :backoff_until
      t.integer :items_count, null: false, default: 0
      t.boolean :scraping_enabled, null: false, default: false
      t.boolean :auto_scrape, null: false, default: false
      t.jsonb :scrape_settings, null: false, default: {}
      t.string :scraper_adapter, null: false, default: "readability"
      t.boolean :requires_javascript, null: false, default: false
      t.jsonb :custom_headers, null: false, default: {}
      t.integer :items_retention_days
      t.integer :max_items
      t.jsonb :metadata, null: false, default: {}

      t.timestamps
    end

    add_index :sourcemon_sources, :feed_url, unique: true
    add_index :sourcemon_sources, :active
    add_index :sourcemon_sources, :next_fetch_at
  end
end
