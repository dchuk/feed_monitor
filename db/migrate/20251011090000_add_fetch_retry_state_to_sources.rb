# frozen_string_literal: true

class AddFetchRetryStateToSources < ActiveRecord::Migration[7.2]
  def change
    change_table :feed_monitor_sources, bulk: true do |t|
      t.integer :fetch_retry_attempt, null: false, default: 0
      t.datetime :fetch_circuit_opened_at
      t.datetime :fetch_circuit_until
    end

    add_index :feed_monitor_sources, :fetch_retry_attempt
    add_index :feed_monitor_sources, :fetch_circuit_until
  end
end
