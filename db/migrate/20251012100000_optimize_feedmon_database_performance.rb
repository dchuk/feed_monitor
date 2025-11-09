# frozen_string_literal: true

class OptimizeFeedmonDatabasePerformance < ActiveRecord::Migration[8.0]
  def change
    add_index :feedmon_sources, :created_at, name: "index_feedmon_sources_on_created_at" unless index_exists?(:feedmon_sources, :created_at)

    unless index_exists?(:feedmon_items, %i[source_id published_at created_at])
      add_index :feedmon_items, %i[source_id published_at created_at], name: "index_feedmon_items_on_source_and_published_at"
    end

    add_index :feedmon_scrape_logs, :started_at, name: "index_feedmon_scrape_logs_on_started_at" unless index_exists?(:feedmon_scrape_logs, :started_at)
  end
end
