# frozen_string_literal: true

class AddTypeToSourceMonitorSources < ActiveRecord::Migration[8.0]
  def change
    add_column :sourcemon_sources, :type, :string
    add_index :sourcemon_sources, :type
  end
end
