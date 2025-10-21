# frozen_string_literal: true

require "test_helper"

module FeedMonitor
  module Dashboard
    class QueriesTest < ActiveSupport::TestCase
      include ActiveSupport::Testing::TimeHelpers

      setup do
        FeedMonitor::Metrics.reset!
        FeedMonitor::Item.delete_all
        FeedMonitor::Source.delete_all
        FeedMonitor::FetchLog.delete_all
        FeedMonitor::ScrapeLog.delete_all
      end

      test "stats caches results and minimizes SQL calls" do
        FeedMonitor::Source.create!(
          name: "Cached Source",
          feed_url: "https://example.com/cache.xml",
          active: true,
          failure_count: 1,
          last_error: "Timeout"
        )

        queries = FeedMonitor::Dashboard::Queries.new

        first_call_queries = count_sql_queries { queries.stats }
        assert_operator first_call_queries, :<=, 3, "expected at most three SQL statements for stats"

        cached_call_queries = count_sql_queries { queries.stats }
        assert_equal 0, cached_call_queries, "expected cached stats to avoid additional SQL"
      end

      test "recent_activity returns events without route data and caches by limit" do
        source = FeedMonitor::Source.create!(
          name: "Activity Source",
          feed_url: "https://example.com/activity.xml"
        )

        FeedMonitor::FetchLog.create!(
          source:,
          started_at: Time.current,
          success: true,
          items_created: 2,
          items_updated: 1
        )

        item = FeedMonitor::Item.create!(
          source:,
          guid: "recent-item",
          url: "https://example.com/items/1",
          title: "Recent Item",
          created_at: Time.current,
          published_at: Time.current
        )

        FeedMonitor::ScrapeLog.create!(
          source:,
          item:,
          started_at: Time.current,
          success: false,
          scraper_adapter: "readability"
        )

        queries = FeedMonitor::Dashboard::Queries.new

        events = queries.recent_activity(limit: 5)
        assert events.all? { |event| event.is_a?(FeedMonitor::Dashboard::RecentActivity::Event) }
        assert events.none? { |event| event.respond_to?(:path) }, "events should not expose routing information"

        cached_call_queries = count_sql_queries { queries.recent_activity(limit: 5) }
        assert_equal 0, cached_call_queries, "expected cached recent activity for identical limit"

        different_limit_queries = count_sql_queries { queries.recent_activity(limit: 2) }
        assert_operator different_limit_queries, :<=, 2, "expected at most two SQL statements for distinct limit cache"
      end

      test "stats instrumentation records duration metrics" do
        queries = FeedMonitor::Dashboard::Queries.new
        events = []

        subscriber = ActiveSupport::Notifications.subscribe("feed_monitor.dashboard.stats") do |*args|
          events << ActiveSupport::Notifications::Event.new(*args)
        end

        queries.stats

        assert_equal 1, events.size, "expected a dashboard stats instrumentation event"
        payload = events.first.payload
        assert payload[:duration_ms].present?, "expected payload duration in milliseconds"
        assert payload[:recorded_at].present?, "expected payload recorded_at timestamp"

        assert FeedMonitor::Metrics.gauge_value(:dashboard_stats_duration_ms), "expected metrics gauge for duration"
        assert FeedMonitor::Metrics.gauge_value(:dashboard_stats_last_run_at_epoch), "expected metrics gauge for last run timestamp"

        FeedMonitor::Metrics.reset!
      ensure
        ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
      end

      test "job_metrics maps summaries to configured queue roles" do
        queries = FeedMonitor::Dashboard::Queries.new
        fetch_summary = FeedMonitor::Jobs::SolidQueueMetrics::QueueSummary.new(
          queue_name: FeedMonitor.queue_name(:fetch),
          ready_count: 2,
          scheduled_count: 1,
          failed_count: 0,
          recurring_count: 1,
          paused: false,
          last_enqueued_at: Time.current,
          last_started_at: nil,
          last_finished_at: nil,
          available: true
        )

        FeedMonitor::Jobs::SolidQueueMetrics.stub(:call, { FeedMonitor.queue_name(:fetch) => fetch_summary }) do
          metrics = queries.job_metrics

          assert_equal [ :fetch, :scrape ], metrics.map { |row| row[:role] }
          fetch_row = metrics.detect { |row| row[:role] == :fetch }
          assert_equal fetch_summary, fetch_row[:summary]

          scrape_row = metrics.detect { |row| row[:role] == :scrape }
          assert_equal FeedMonitor.queue_name(:scrape), scrape_row[:queue_name]
          assert_equal 0, scrape_row[:summary].ready_count
          refute scrape_row[:summary].available
        end
      end

      test "upcoming_fetch_schedule caches grouped sources" do
        source = FeedMonitor::Source.create!(
          name: "Schedule Source",
          feed_url: "https://example.com/schedule.xml",
          next_fetch_at: Time.current + 15.minutes
        )

        queries = FeedMonitor::Dashboard::Queries.new

        first_groups = queries.upcoming_fetch_schedule.groups
        assert_equal 1, first_groups.find { |group| group.key == "0-30" }.sources.size

        FeedMonitor::Source.where(id: source.id).update_all(next_fetch_at: Time.current + 5.hours)

        cached_groups = queries.upcoming_fetch_schedule.groups
        assert_equal 1, cached_groups.find { |group| group.key == "0-30" }.sources.size
      end

      test "recent_activity caches results per limit key" do
        queries = FeedMonitor::Dashboard::Queries.new
        fake_cache = Struct.new(:calls) do
          def fetch(key)
            calls << key
            yield
          end
        end.new([])

        queries.instance_variable_set(:@cache, fake_cache)

        fake_query = Minitest::Mock.new
        fake_query.expect :call, []

        FeedMonitor::Dashboard::Queries::RecentActivityQuery.stub(:new, ->(**kwargs) {
          assert_equal 5, kwargs[:limit]
          fake_query
        }) { queries.recent_activity(limit: 5) }

        fake_query.verify

        assert_includes fake_cache.calls, [ :recent_activity, 5 ]
      end

      test "recent_activity_query sanitizes SQL with the provided limit" do
        query = FeedMonitor::Dashboard::Queries::RecentActivityQuery.new(limit: 3)

        sql = query.send(:sanitized_sql)

        assert_includes sql, "LIMIT 3"
      end

      private

      def count_sql_queries
        queries = []
        subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |_name, _start, _finish, _id, payload|
          next if payload[:name] == "SCHEMA"

          queries << payload[:sql]
        end

        yield
        queries.count
      ensure
        ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
      end
    end
  end
end
