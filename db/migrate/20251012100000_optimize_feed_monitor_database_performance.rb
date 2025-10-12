# frozen_string_literal: true

class OptimizeFeedMonitorDatabasePerformance < ActiveRecord::Migration[8.0]
  def change
    add_index :feed_monitor_sources, :created_at, name: "index_feed_monitor_sources_on_created_at" unless index_exists?(:feed_monitor_sources, :created_at)

    unless index_exists?(:feed_monitor_items, %i[source_id published_at created_at])
      add_index :feed_monitor_items, %i[source_id published_at created_at], name: "index_feed_monitor_items_on_source_and_published_at"
    end

    add_index :feed_monitor_scrape_logs, :started_at, name: "index_feed_monitor_scrape_logs_on_started_at" unless index_exists?(:feed_monitor_scrape_logs, :started_at)
  end
end
