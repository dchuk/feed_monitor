# frozen_string_literal: true

class AddTypeToFeedmonSources < ActiveRecord::Migration[8.0]
  def change
    add_column :feedmon_sources, :type, :string
    add_index :feedmon_sources, :type
  end
end
