# frozen_string_literal: true

class AddFetchStatusToFeedmonSources < ActiveRecord::Migration[8.0]
  def change
    add_column :feedmon_sources, :fetch_status, :string, default: "idle", null: false
    add_column :feedmon_sources, :last_fetch_started_at, :datetime
    add_index :feedmon_sources, :fetch_status
  end
end
