# frozen_string_literal: true

class AddDeletedAtToFeedmonItems < ActiveRecord::Migration[8.0]
  def change
    add_column :feedmon_items, :deleted_at, :datetime
    add_index :feedmon_items, :deleted_at
  end
end
