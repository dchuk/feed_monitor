# frozen_string_literal: true

class CreateFeedmonFetchLogs < ActiveRecord::Migration[8.0]
  def change
    create_table :feedmon_fetch_logs do |t|
      t.references :source, null: false, foreign_key: { to_table: :feedmon_sources }
      t.boolean :success, null: false, default: false
      t.integer :items_created, null: false, default: 0
      t.integer :items_updated, null: false, default: 0
      t.integer :items_failed, null: false, default: 0
      t.datetime :started_at, null: false
      t.datetime :completed_at
      t.integer :duration_ms
      t.integer :http_status
      t.jsonb :http_response_headers, null: false, default: {}
      t.string :error_class
      t.text :error_message
      t.text :error_backtrace
      t.integer :feed_size_bytes
      t.integer :items_in_feed
      t.string :job_id
      t.jsonb :metadata, null: false, default: {}

      t.timestamps
    end

    add_index :feedmon_fetch_logs, :success
    add_index :feedmon_fetch_logs, :started_at
    add_index :feedmon_fetch_logs, :job_id
    add_index :feedmon_fetch_logs, :created_at
  end
end
