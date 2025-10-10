# frozen_string_literal: true

class AddTypeToFeedMonitorSources < ActiveRecord::Migration[8.0]
  def change
    add_column :feed_monitor_sources, :type, :string
    add_index :feed_monitor_sources, :type
  end
end
