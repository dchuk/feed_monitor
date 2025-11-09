# frozen_string_literal: true

class CreateSourceMonitorHealthCheckLogs < ActiveRecord::Migration[7.2]
  def change
    create_table :sourcemon_health_check_logs do |t|
      t.references :source, null: false, foreign_key: { to_table: :sourcemon_sources }
      t.boolean :success, null: false, default: false
      t.datetime :started_at, null: false
      t.datetime :completed_at
      t.integer :duration_ms
      t.integer :http_status
      t.jsonb :http_response_headers, null: false, default: {}
      t.string :error_class
      t.text :error_message

      t.timestamps
    end

    add_index :sourcemon_health_check_logs, :started_at
    add_index :sourcemon_health_check_logs, :success
  end
end
