# frozen_string_literal: true

class CreateFeedMonitorScrapeLogs < ActiveRecord::Migration[8.0]
  def change
    create_table :feed_monitor_scrape_logs do |t|
      t.references :item, null: false, foreign_key: { to_table: :feed_monitor_items }
      t.references :source, null: false, foreign_key: { to_table: :feed_monitor_sources }
      t.boolean :success, null: false, default: false
      t.datetime :started_at, null: false
      t.datetime :completed_at
      t.integer :duration_ms
      t.integer :http_status
      t.string :scraper_adapter
      t.integer :content_length
      t.string :error_class
      t.text :error_message
      t.jsonb :metadata, null: false, default: {}

      t.timestamps
    end

    add_index :feed_monitor_scrape_logs, :success
    add_index :feed_monitor_scrape_logs, :created_at
  end
end
