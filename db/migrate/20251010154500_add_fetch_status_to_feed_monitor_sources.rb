# frozen_string_literal: true

class AddFetchStatusToFeedMonitorSources < ActiveRecord::Migration[8.0]
  def change
    add_column :feed_monitor_sources, :fetch_status, :string, default: "idle", null: false
    add_column :feed_monitor_sources, :last_fetch_started_at, :datetime
    add_index :feed_monitor_sources, :fetch_status
  end
end
