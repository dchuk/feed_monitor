# frozen_string_literal: true

class OptimizeSourceMonitorDatabasePerformance < ActiveRecord::Migration[8.0]
  def change
    add_index :sourcemon_sources, :created_at, name: "index_sourcemon_sources_on_created_at" unless index_exists?(:sourcemon_sources, :created_at)

    unless index_exists?(:sourcemon_items, %i[source_id published_at created_at])
      add_index :sourcemon_items, %i[source_id published_at created_at], name: "index_sourcemon_items_on_source_and_published_at"
    end

    add_index :sourcemon_scrape_logs, :started_at, name: "index_sourcemon_scrape_logs_on_started_at" unless index_exists?(:sourcemon_scrape_logs, :started_at)
  end
end
