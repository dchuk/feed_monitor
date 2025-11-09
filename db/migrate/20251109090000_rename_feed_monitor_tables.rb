# frozen_string_literal: true

class RenameFeedMonitorTables < ActiveRecord::Migration[8.0]
  TABLE_RENAMES = {
    feed_monitor_sources: :feedmon_sources,
    feed_monitor_items: :feedmon_items,
    feed_monitor_fetch_logs: :feedmon_fetch_logs,
    feed_monitor_scrape_logs: :feedmon_scrape_logs,
    feed_monitor_item_contents: :feedmon_item_contents,
    feed_monitor_log_entries: :feedmon_log_entries,
    feed_monitor_health_check_logs: :feedmon_health_check_logs
  }.freeze

  INDEX_RENAMES = {
    feedmon_sources: {
      index_feed_monitor_sources_on_feed_url: :index_feedmon_sources_on_feed_url,
      index_feed_monitor_sources_on_active: :index_feedmon_sources_on_active,
      index_feed_monitor_sources_on_next_fetch_at: :index_feedmon_sources_on_next_fetch_at,
      index_feed_monitor_sources_on_created_at: :index_feedmon_sources_on_created_at,
      index_feed_monitor_sources_on_health_status: :index_feedmon_sources_on_health_status,
      index_feed_monitor_sources_on_auto_paused_until: :index_feedmon_sources_on_auto_paused_until,
      index_feed_monitor_sources_on_fetch_retry_attempt: :index_feedmon_sources_on_fetch_retry_attempt,
      index_feed_monitor_sources_on_fetch_circuit_until: :index_feedmon_sources_on_fetch_circuit_until,
      index_feed_monitor_sources_on_fetch_status: :index_feedmon_sources_on_fetch_status,
      index_feed_monitor_sources_on_type: :index_feedmon_sources_on_type
    },
    feedmon_items: {
      index_feed_monitor_items_on_guid: :index_feedmon_items_on_guid,
      index_feed_monitor_items_on_content_fingerprint: :index_feedmon_items_on_content_fingerprint,
      index_feed_monitor_items_on_url: :index_feedmon_items_on_url,
      index_feed_monitor_items_on_scrape_status: :index_feedmon_items_on_scrape_status,
      index_feed_monitor_items_on_published_at: :index_feedmon_items_on_published_at,
      index_feed_monitor_items_on_source_id_and_guid: :index_feedmon_items_on_source_id_and_guid,
      index_feed_monitor_items_on_source_id_and_content_fingerprint: :index_feedmon_items_on_source_id_and_content_fingerprint,
      index_feed_monitor_items_on_deleted_at: :index_feedmon_items_on_deleted_at
    },
    feedmon_fetch_logs: {
      index_feed_monitor_fetch_logs_on_success: :index_feedmon_fetch_logs_on_success,
      index_feed_monitor_fetch_logs_on_started_at: :index_feedmon_fetch_logs_on_started_at,
      index_feed_monitor_fetch_logs_on_job_id: :index_feedmon_fetch_logs_on_job_id,
      index_feed_monitor_fetch_logs_on_created_at: :index_feedmon_fetch_logs_on_created_at
    },
    feedmon_scrape_logs: {
      index_feed_monitor_scrape_logs_on_success: :index_feedmon_scrape_logs_on_success,
      index_feed_monitor_scrape_logs_on_created_at: :index_feedmon_scrape_logs_on_created_at,
      index_feed_monitor_scrape_logs_on_started_at: :index_feedmon_scrape_logs_on_started_at
    },
    feedmon_item_contents: {
      index_feed_monitor_item_contents_on_item_id: :index_feedmon_item_contents_on_item_id
    },
    feedmon_log_entries: {
      index_feed_monitor_log_entries_on_started_at: :index_feedmon_log_entries_on_started_at,
      index_feed_monitor_log_entries_on_success: :index_feedmon_log_entries_on_success,
      index_feed_monitor_log_entries_on_scraper_adapter: :index_feedmon_log_entries_on_scraper_adapter
    },
    feedmon_health_check_logs: {
      index_feed_monitor_health_check_logs_on_started_at: :index_feedmon_health_check_logs_on_started_at,
      index_feed_monitor_health_check_logs_on_success: :index_feedmon_health_check_logs_on_success
    }
  }.freeze

  def up
    TABLE_RENAMES.each do |old_name, new_name|
      next unless table_exists?(old_name)
      next if table_exists?(new_name)

      rename_table old_name, new_name
    end

    INDEX_RENAMES.each do |table_name, indexes|
      indexes.each do |old_name, new_name|
        rename_index_if_exists(table_name, old_name, new_name)
      end
    end
  end

  def down
    INDEX_RENAMES.each do |table_name, indexes|
      indexes.each do |old_name, new_name|
        rename_index_if_exists(table_name, new_name, old_name)
      end
    end

    TABLE_RENAMES.each do |old_name, new_name|
      next unless table_exists?(new_name)
      next if table_exists?(old_name)

      rename_table new_name, old_name
    end
  end

  private

  def rename_index_if_exists(table_name, old_name, new_name)
    return unless table_exists?(table_name)
    return unless index_name_exists?(table_name, old_name)

    rename_index(table_name, old_name, new_name)
  end
end
