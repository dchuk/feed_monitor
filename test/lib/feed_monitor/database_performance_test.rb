# frozen_string_literal: true

require "test_helper"

module FeedMonitor
  class DatabasePerformanceTest < ActiveSupport::TestCase
    include ActiveSupport::Testing::TimeHelpers

    setup do
      FeedMonitor::Item.delete_all
      FeedMonitor::Source.delete_all
      FeedMonitor::FetchLog.delete_all
      FeedMonitor::ScrapeLog.delete_all
    end

    test "critical tables expose required indexes" do
      assert_has_index(:feed_monitor_sources, %w[feed_url])
      assert_has_index(:feed_monitor_sources, %w[next_fetch_at])
      assert_has_index(:feed_monitor_sources, %w[created_at])

      assert_has_index(:feed_monitor_items, %w[source_id published_at created_at])

      assert_has_index(:feed_monitor_scrape_logs, %w[started_at])
    end

    test "retention pruner soft deletes update counter cache with a single statement" do
      source = FeedMonitor::Source.create!(
        name: "Soft Delete Source",
        feed_url: "https://example.com/soft-delete.xml",
        items_retention_days: 1
      )

      travel_to Time.zone.local(2025, 10, 1, 12, 0, 0) do
        3.times do |index|
          FeedMonitor::Item.create!(
            source:,
            guid: "item-#{index}",
            url: "https://example.com/items/#{index}",
            title: "Item #{index}",
            published_at: Time.current
          )
        end
      end

      assert_equal 3, source.reload.items_count

      update_statements = capture_sql do
        travel_to Time.zone.local(2025, 10, 5, 12, 0, 0) do
          FeedMonitor::Items::RetentionPruner.call(source:, strategy: :soft_delete)
        end
      end.select { |sql| sql.include?('UPDATE "feed_monitor_sources"') && sql.include?('"items_count"') }

      assert_equal 1, update_statements.size, "expected a single items_count update statement"
      assert_equal 0, source.reload.items_count
      assert_equal 3, FeedMonitor::Item.only_deleted.count
    end

    test "dashboard recent activity avoids N+1 queries for item sources" do
      source = FeedMonitor::Source.create!(
        name: "Activity Source",
        feed_url: "https://example.com/activity.xml"
      )

      2.times do |index|
        FeedMonitor::FetchLog.create!(
          source:,
          started_at: Time.current - index.minutes,
          success: true
        )
      end

      2.times do |index|
        FeedMonitor::ScrapeLog.create!(
          source:,
          item: FeedMonitor::Item.create!(
            source:,
            guid: "scrape-item-#{index}",
            url: "https://example.com/scrapes/#{index}",
            title: "Scrape #{index}",
            published_at: Time.current - index.hours
          ),
          started_at: Time.current - index.minutes,
          success: true
        )
      end

      3.times do |index|
        FeedMonitor::Item.create!(
          source:,
          guid: "recent-item-#{index}",
          url: "https://example.com/recent/#{index}",
          title: "Recent #{index}",
          published_at: Time.current - index.hours
        )
      end

      query_count = count_sql_queries do
        FeedMonitor::Dashboard::Queries.recent_activity(limit: 3)
      end

      assert_operator query_count, :<=, 4, "expected recent_activity to execute at most four SQL queries"
    end

    private

    def assert_has_index(table, columns)
      expected_columns = Array(columns).map(&:to_s)
      index = ActiveRecord::Base.connection.indexes(table).find do |idx|
        idx.columns == expected_columns
      end
      assert index, "expected index on #{table} for columns #{expected_columns.join(', ')}"
    end

    def count_sql_queries(&block)
      queries = capture_sql(&block)
      queries.count { |sql| sql !~ /\A(?:BEGIN|COMMIT|ROLLBACK|SAVEPOINT|RELEASE)/ }
    end

    def capture_sql
      queries = []
      subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |_name, _start, _finish, _id, payload|
        next if payload[:name] == "SCHEMA"

        queries << payload[:sql]
      end

      yield
      queries
    ensure
      ActiveSupport::Notifications.unsubscribe(subscriber)
    end
  end
end
