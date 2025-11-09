# frozen_string_literal: true

require "active_support/notifications"
require "feedmon/dashboard/upcoming_fetch_schedule"

module Feedmon
  module Dashboard
    class Queries
      def initialize(reference_time: Time.current)
        @reference_time = reference_time
        @cache = Cache.new
      end

      def stats
        cache.fetch(:stats) do
          measure(:stats) do
            StatsQuery.new(reference_time:).call
          end
        end
      end

      def recent_activity(limit: DEFAULT_RECENT_ACTIVITY_LIMIT)
        cache.fetch([ :recent_activity, limit ]) do
          measure(:recent_activity, limit:) do
            RecentActivityQuery.new(limit:).call
          end
        end
      end

      def quick_actions
        QUICK_ACTIONS
      end

      def job_metrics(queue_names: queue_name_map.values)
        measure(:job_metrics, queue_names:) do
          summaries = Feedmon::Jobs::SolidQueueMetrics.call(queue_names:)

          queue_name_map.map do |role, queue_name|
            summary = summaries[queue_name.to_s] || Feedmon::Jobs::SolidQueueMetrics::QueueSummary.new(
              queue_name: queue_name.to_s,
              ready_count: 0,
              scheduled_count: 0,
              failed_count: 0,
              recurring_count: 0,
              paused: false,
              last_enqueued_at: nil,
              last_started_at: nil,
              last_finished_at: nil,
              available: false
            )

            {
              role: role,
              queue_name: queue_name,
              summary: summary
            }
          end
        end
      end

      def upcoming_fetch_schedule
        cache.fetch(:upcoming_fetch_schedule) do
          measure(:upcoming_fetch_schedule) do
            Feedmon::Dashboard::UpcomingFetchSchedule.new(scope: Feedmon::Source.active)
          end
        end
      end

      private

      DEFAULT_RECENT_ACTIVITY_LIMIT = 8

      attr_reader :reference_time, :cache

      def measure(name, metadata = {})
        started_at = monotonic_time
        result = yield
        duration_ms = ((monotonic_time - started_at) * 1000.0).round(2)
        recorded_at = Time.current

        payload = metadata.merge(duration_ms:, recorded_at:)
        ActiveSupport::Notifications.instrument("feedmon.dashboard.#{name}", payload)
        record_metrics(name, result, duration_ms:, recorded_at:, metadata:)

        result
      end

      def record_metrics(name, result, duration_ms:, recorded_at:, metadata:)
        Feedmon::Metrics.gauge(:"dashboard_#{name}_duration_ms", duration_ms)
        Feedmon::Metrics.gauge(:"dashboard_#{name}_last_run_at_epoch", recorded_at.to_f)

        case name
        when :stats
          record_stats_metrics(result)
        when :recent_activity
          Feedmon::Metrics.gauge(:dashboard_recent_activity_events_count, result.size)
          Feedmon::Metrics.gauge(:dashboard_recent_activity_limit, metadata[:limit]) if metadata[:limit]
        when :job_metrics
          Feedmon::Metrics.gauge(:dashboard_job_metrics_queue_count, result.size)
        when :upcoming_fetch_schedule
          Feedmon::Metrics.gauge(:dashboard_fetch_schedule_group_count, result.groups.size)
        end
      end

      def record_stats_metrics(stats)
        Feedmon::Metrics.gauge(:dashboard_stats_total_sources, stats[:total_sources])
        Feedmon::Metrics.gauge(:dashboard_stats_active_sources, stats[:active_sources])
        Feedmon::Metrics.gauge(:dashboard_stats_failed_sources, stats[:failed_sources])
        Feedmon::Metrics.gauge(:dashboard_stats_total_items, stats[:total_items])
        Feedmon::Metrics.gauge(:dashboard_stats_fetches_today, stats[:fetches_today])
      end

      def queue_name_map
        @queue_name_map ||= {
          fetch: Feedmon.queue_name(:fetch),
          scrape: Feedmon.queue_name(:scrape)
        }
      end

      def monotonic_time
        Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end

      class Cache
        def initialize
          @store = {}
        end

        def fetch(key)
          if store.key?(key)
            store.fetch(key)
          else
            store[key] = yield
          end
        end

        private

        attr_reader :store
      end

      class StatsQuery
        def initialize(reference_time:)
          @reference_time = reference_time
        end

        def call
          {
            total_sources: integer_value(source_counts["total_sources"]),
            active_sources: integer_value(source_counts["active_sources"]),
            failed_sources: integer_value(source_counts["failed_sources"]),
            total_items: total_items_count,
            fetches_today: fetches_today_count
          }
        end

        private

        attr_reader :reference_time

        def source_counts
          @source_counts ||= begin
            Feedmon::Source.connection.exec_query(source_counts_sql).first || {}
          end
        end

        def total_items_count
          Feedmon::Item.connection.select_value(total_items_sql).to_i
        end

        def fetches_today_count
          Feedmon::FetchLog.where("started_at >= ?", start_of_day).count
        end

        def source_counts_sql
          <<~SQL.squish
            SELECT
              COUNT(*) AS total_sources,
              SUM(CASE WHEN active THEN 1 ELSE 0 END) AS active_sources,
              SUM(CASE WHEN (#{failure_condition}) THEN 1 ELSE 0 END) AS failed_sources
            FROM #{Feedmon::Source.quoted_table_name}
          SQL
        end

        def failure_condition
          [
            "#{Feedmon::Source.quoted_table_name}.failure_count > 0",
            "#{Feedmon::Source.quoted_table_name}.last_error IS NOT NULL",
            "#{Feedmon::Source.quoted_table_name}.last_error_at IS NOT NULL"
          ].join(" OR ")
        end

        def total_items_sql
          "SELECT COUNT(*) FROM #{Feedmon::Item.quoted_table_name}"
        end

        def start_of_day
          reference_time.in_time_zone.beginning_of_day
        end

        def integer_value(value)
          value.to_i
        end
      end

      class RecentActivityQuery
        EVENT_TYPE_FETCH = "fetch_log"
        EVENT_TYPE_SCRAPE = "scrape_log"
        EVENT_TYPE_ITEM = "item"

        def initialize(limit:)
          @limit = limit
        end

        def call
          rows = connection.exec_query(sanitized_sql)
          rows.map { |row| build_event(row) }
        end

        private

        attr_reader :limit

        def connection
          ActiveRecord::Base.connection
        end

        def build_event(row)
          Feedmon::Dashboard::RecentActivity::Event.new(
            type: row["resource_type"].to_sym,
            id: row["resource_id"],
            occurred_at: row["occurred_at"],
            success: row["success_flag"].to_i == 1,
            items_created: row["items_created"],
            items_updated: row["items_updated"],
            scraper_adapter: row["scraper_adapter"],
            item_title: row["item_title"],
            item_url: row["item_url"],
            source_name: row["source_name"],
            source_id: row["source_id"]
          )
        end

        def sanitized_sql
          ActiveRecord::Base.send(:sanitize_sql_array, [ unified_sql_template, limit ])
        end

        def unified_sql_template
          <<~SQL
            SELECT resource_type,
                   resource_id,
                   occurred_at,
                   success_flag,
                   items_created,
                   items_updated,
                   scraper_adapter,
                   item_title,
                   item_url,
                   source_name,
                   source_id
            FROM (
              #{fetch_log_sql}
              UNION ALL
              #{scrape_log_sql}
              UNION ALL
              #{item_sql}
            ) AS dashboard_events
            WHERE occurred_at IS NOT NULL
            ORDER BY occurred_at DESC
            LIMIT ?
          SQL
        end

        def fetch_log_sql
          <<~SQL
            SELECT
              '#{EVENT_TYPE_FETCH}' AS resource_type,
              #{Feedmon::FetchLog.quoted_table_name}.id AS resource_id,
              #{Feedmon::FetchLog.quoted_table_name}.started_at AS occurred_at,
              CASE WHEN #{Feedmon::FetchLog.quoted_table_name}.success THEN 1 ELSE 0 END AS success_flag,
              #{Feedmon::FetchLog.quoted_table_name}.items_created AS items_created,
              #{Feedmon::FetchLog.quoted_table_name}.items_updated AS items_updated,
              NULL AS scraper_adapter,
              NULL AS item_title,
              NULL AS item_url,
              NULL AS source_name,
              #{Feedmon::FetchLog.quoted_table_name}.source_id AS source_id
            FROM #{Feedmon::FetchLog.quoted_table_name}
          SQL
        end

        def scrape_log_sql
          <<~SQL
            SELECT
              '#{EVENT_TYPE_SCRAPE}' AS resource_type,
              #{Feedmon::ScrapeLog.quoted_table_name}.id AS resource_id,
              #{Feedmon::ScrapeLog.quoted_table_name}.started_at AS occurred_at,
              CASE WHEN #{Feedmon::ScrapeLog.quoted_table_name}.success THEN 1 ELSE 0 END AS success_flag,
              NULL AS items_created,
              NULL AS items_updated,
              #{Feedmon::ScrapeLog.quoted_table_name}.scraper_adapter AS scraper_adapter,
              NULL AS item_title,
              NULL AS item_url,
              #{Feedmon::Source.quoted_table_name}.#{quoted_source_name} AS source_name,
              #{Feedmon::ScrapeLog.quoted_table_name}.source_id AS source_id
            FROM #{Feedmon::ScrapeLog.quoted_table_name}
            LEFT JOIN #{Feedmon::Source.quoted_table_name}
              ON #{Feedmon::Source.quoted_table_name}.id = #{Feedmon::ScrapeLog.quoted_table_name}.source_id
          SQL
        end

        def item_sql
          <<~SQL
            SELECT
              '#{EVENT_TYPE_ITEM}' AS resource_type,
              #{Feedmon::Item.quoted_table_name}.id AS resource_id,
              #{Feedmon::Item.quoted_table_name}.created_at AS occurred_at,
              1 AS success_flag,
              NULL AS items_created,
              NULL AS items_updated,
              NULL AS scraper_adapter,
              #{Feedmon::Item.quoted_table_name}.title AS item_title,
              #{Feedmon::Item.quoted_table_name}.url AS item_url,
              #{Feedmon::Source.quoted_table_name}.#{quoted_source_name} AS source_name,
              #{Feedmon::Item.quoted_table_name}.source_id AS source_id
            FROM #{Feedmon::Item.quoted_table_name}
            LEFT JOIN #{Feedmon::Source.quoted_table_name}
              ON #{Feedmon::Source.quoted_table_name}.id = #{Feedmon::Item.quoted_table_name}.source_id
          SQL
        end

        def quoted_source_name
          ActiveRecord::Base.connection.quote_column_name("name")
        end
      end

      QUICK_ACTIONS = [
        Feedmon::Dashboard::QuickAction.new(
          label: "Add Source",
          description: "Create a new feed source",
          route_name: :new_source_path
        ).freeze,
        Feedmon::Dashboard::QuickAction.new(
          label: "View Sources",
          description: "Manage existing sources",
          route_name: :sources_path
        ).freeze,
        Feedmon::Dashboard::QuickAction.new(
          label: "Check Health",
          description: "Verify engine status",
          route_name: :health_path
        ).freeze
      ].freeze
    end
  end
end
