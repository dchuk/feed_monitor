# frozen_string_literal: true

class AddDeletedAtToFeedMonitorItems < ActiveRecord::Migration[8.0]
  def change
    add_column :feed_monitor_items, :deleted_at, :datetime
    add_index :feed_monitor_items, :deleted_at
  end
end
