# frozen_string_literal: true

class AddAdaptiveFetchingToggleToSources < ActiveRecord::Migration[7.1]
  def change
    add_column :feed_monitor_sources, :adaptive_fetching_enabled, :boolean, null: false, default: true
  end
end
