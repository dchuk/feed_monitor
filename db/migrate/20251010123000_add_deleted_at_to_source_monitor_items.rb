# frozen_string_literal: true

class AddDeletedAtToSourceMonitorItems < ActiveRecord::Migration[8.0]
  def change
    add_column :sourcemon_items, :deleted_at, :datetime
    add_index :sourcemon_items, :deleted_at
  end
end
