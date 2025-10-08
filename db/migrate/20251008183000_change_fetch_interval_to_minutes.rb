# frozen_string_literal: true

class ChangeFetchIntervalToMinutes < ActiveRecord::Migration[8.0]
  def up
    rename_column :feed_monitor_sources, :fetch_interval_hours, :fetch_interval_minutes
    change_column_default :feed_monitor_sources, :fetch_interval_minutes, 360

    execute <<~SQL
      UPDATE feed_monitor_sources
      SET fetch_interval_minutes = fetch_interval_minutes * 60
    SQL
  end

  def down
    execute <<~SQL
      UPDATE feed_monitor_sources
      SET fetch_interval_minutes = GREATEST(1, ROUND(fetch_interval_minutes::numeric / 60.0))
    SQL

    change_column_default :feed_monitor_sources, :fetch_interval_minutes, 6
    rename_column :feed_monitor_sources, :fetch_interval_minutes, :fetch_interval_hours
  end
end
