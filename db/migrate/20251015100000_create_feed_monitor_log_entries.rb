# frozen_string_literal: true

class CreateFeedMonitorLogEntries < ActiveRecord::Migration[7.1]
  def change
    create_table :feed_monitor_log_entries do |t|
      t.references :loggable, polymorphic: true, null: false, index: { name: "index_feed_monitor_log_entries_on_loggable" }
      t.references :source, null: false, foreign_key: { to_table: :feed_monitor_sources }
      t.references :item, foreign_key: { to_table: :feed_monitor_items }
      t.boolean :success, null: false, default: false
      t.datetime :started_at, null: false
      t.datetime :completed_at
      t.integer :http_status
      t.integer :duration_ms
      t.integer :items_created
      t.integer :items_updated
      t.integer :items_failed
      t.string :scraper_adapter
      t.integer :content_length
      t.string :error_class
      t.text :error_message

      t.timestamps
    end

    add_index :feed_monitor_log_entries, :started_at
    add_index :feed_monitor_log_entries, :success
    add_index :feed_monitor_log_entries, :scraper_adapter

    reversible do |direction|
      direction.up do
        say_with_time "Backfilling feed_monitor_log_entries" do
          fetch_log_class = Class.new(ActiveRecord::Base) do
            self.table_name = "feed_monitor_fetch_logs"
          end

          scrape_log_class = Class.new(ActiveRecord::Base) do
            self.table_name = "feed_monitor_scrape_logs"
          end

          log_entry_class = Class.new(ActiveRecord::Base) do
            self.table_name = "feed_monitor_log_entries"
          end

          fetch_log_class.find_each do |log|
            log_entry_class.create!(
              loggable_type: "FeedMonitor::FetchLog",
              loggable_id: log.id,
              source_id: log.source_id,
              item_id: nil,
              success: log.success,
              started_at: log.started_at,
              completed_at: log.completed_at,
              http_status: log.http_status,
              duration_ms: log.duration_ms,
              items_created: log.items_created,
              items_updated: log.items_updated,
              items_failed: log.items_failed,
              scraper_adapter: nil,
              content_length: nil,
              error_class: log.error_class,
              error_message: log.error_message
            )
          end

          scrape_log_class.find_each do |log|
            log_entry_class.create!(
              loggable_type: "FeedMonitor::ScrapeLog",
              loggable_id: log.id,
              source_id: log.source_id,
              item_id: log.item_id,
              success: log.success,
              started_at: log.started_at,
              completed_at: log.completed_at,
              http_status: log.http_status,
              duration_ms: log.duration_ms,
              items_created: nil,
              items_updated: nil,
              items_failed: nil,
              scraper_adapter: log.scraper_adapter,
              content_length: log.content_length,
              error_class: log.error_class,
              error_message: log.error_message
            )
          end
        end
      end
    end
  end
end
