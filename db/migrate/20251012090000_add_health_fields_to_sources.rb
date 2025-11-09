# frozen_string_literal: true

class AddHealthFieldsToSources < ActiveRecord::Migration[8.0]
  def change
    change_table :sourcemon_sources, bulk: true do |t|
      t.decimal :rolling_success_rate, precision: 5, scale: 4
      t.string :health_status, null: false, default: "healthy"
      t.datetime :health_status_changed_at
      t.datetime :auto_paused_at
      t.datetime :auto_paused_until
      t.decimal :health_auto_pause_threshold, precision: 5, scale: 4
    end

    add_index :sourcemon_sources, :health_status
    add_index :sourcemon_sources, :auto_paused_until
  end
end
