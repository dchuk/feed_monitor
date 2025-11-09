# frozen_string_literal: true

class AddFetchStatusToSourceMonitorSources < ActiveRecord::Migration[8.0]
  def change
    add_column :sourcemon_sources, :fetch_status, :string, default: "idle", null: false
    add_column :sourcemon_sources, :last_fetch_started_at, :datetime
    add_index :sourcemon_sources, :fetch_status
  end
end
