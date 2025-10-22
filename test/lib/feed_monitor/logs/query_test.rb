# frozen_string_literal: true

require "test_helper"

module FeedMonitor
  module Logs
    class QueryTest < ActiveSupport::TestCase
      def setup
        travel_to Time.zone.local(2025, 10, 15, 10, 0, 0)

        @source_a = create_source!(name: "Source A")
        @source_b = create_source!(name: "Source B")

        @item_a = FeedMonitor::Item.create!(
          source: @source_a,
          guid: SecureRandom.uuid,
          title: "Primary Item",
          url: "https://example.com/articles/primary"
        )

        @item_b = FeedMonitor::Item.create!(
          source: @source_b,
          guid: SecureRandom.uuid,
          title: "Secondary Item",
          url: "https://example.com/articles/secondary"
        )

        @recent_fetch = FeedMonitor::FetchLog.create!(
          source: @source_a,
          success: true,
          http_status: 200,
          items_created: 2,
          items_updated: 1,
          items_failed: 0,
          started_at: 30.minutes.ago,
          error_message: "OK"
        )

        @older_fetch = FeedMonitor::FetchLog.create!(
          source: @source_b,
          success: false,
          http_status: 500,
          items_created: 0,
          items_updated: 0,
          items_failed: 1,
          started_at: 3.days.ago,
          error_message: "Timeout while fetching"
        )

        @recent_scrape = FeedMonitor::ScrapeLog.create!(
          source: @source_a,
          item: @item_a,
          success: false,
          http_status: 502,
          scraper_adapter: "readability",
          duration_ms: 1200,
          started_at: 20.minutes.ago,
          error_message: "Readability parse error"
        )

        @older_scrape = FeedMonitor::ScrapeLog.create!(
          source: @source_b,
          item: @item_b,
          success: true,
          http_status: 200,
          scraper_adapter: "mercury",
          duration_ms: 900,
          started_at: 5.days.ago
        )

        @health_check = FeedMonitor::HealthCheckLog.create!(
          source: @source_a,
          success: true,
          http_status: 204,
          started_at: 10.minutes.ago,
          duration_ms: 400
        )

        @recent_fetch_entry = @recent_fetch.reload.log_entry
        @older_fetch_entry = @older_fetch.reload.log_entry
        @recent_scrape_entry = @recent_scrape.reload.log_entry
        @older_scrape_entry = @older_scrape.reload.log_entry
        @health_check_entry = @health_check.reload.log_entry
      end

      def teardown
        travel_back
      end

      test "returns entries ordered by newest started_at first" do
        result = FeedMonitor::Logs::Query.new(params: {}).call

        assert_equal [ @health_check_entry.id, @recent_scrape_entry.id, @recent_fetch_entry.id, @older_fetch_entry.id, @older_scrape_entry.id ],
                     result.entries.map(&:id)
        assert_equal [ :health_check, :scrape, :fetch, :fetch, :scrape ],
                     result.entries.map(&:log_type)
      end

      test "filters by log type" do
        result = FeedMonitor::Logs::Query.new(params: { log_type: "fetch" }).call

        assert_equal [ :fetch, :fetch ], result.entries.map(&:log_type)
        assert_equal [ @recent_fetch_entry.id, @older_fetch_entry.id ], result.entries.map(&:id)
      end

      test "filters health check logs" do
        result = FeedMonitor::Logs::Query.new(params: { log_type: "health_check" }).call

        assert_equal [ :health_check ], result.entries.map(&:log_type)
        assert_equal [ @health_check_entry.id ], result.entries.map(&:id)
      end

      test "filters by status" do
        result = FeedMonitor::Logs::Query.new(params: { status: "failed" }).call

        assert_equal [ :scrape, :fetch ], result.entries.map(&:log_type)
        assert_equal [ @recent_scrape_entry.id, @older_fetch_entry.id ], result.entries.map(&:id)
        assert result.entries.all? { |entry| entry.success? == false }
      end

      test "filters by timeframe shortcut" do
        result = FeedMonitor::Logs::Query.new(params: { timeframe: "24h" }).call

        assert_equal [ @health_check_entry.id, @recent_scrape_entry.id, @recent_fetch_entry.id ], result.entries.map(&:id)
      end

      test "filters by explicit started_at range" do
        result = FeedMonitor::Logs::Query.new(
          params: {
            started_after: 36.hours.ago.iso8601,
            started_before: 10.minutes.from_now.iso8601
          }
        ).call

        assert_equal [ @health_check_entry.id, @recent_scrape_entry.id, @recent_fetch_entry.id ], result.entries.map(&:id)
      end

      test "filters by source id" do
        result = FeedMonitor::Logs::Query.new(params: { source_id: @source_a.id.to_s }).call

        assert_equal [ :health_check, :scrape, :fetch ], result.entries.map(&:log_type)
        assert result.entries.all? { |entry| entry.source_id == @source_a.id }
      end

      test "filters scrape logs by item id" do
        result = FeedMonitor::Logs::Query.new(params: { item_id: @item_a.id }).call

        assert_equal [ :scrape ], result.entries.map(&:log_type)
        assert_equal [ @recent_scrape_entry.id ], result.entries.map(&:id)
      end

      test "performs case-insensitive search across title, source, and error message" do
        result = FeedMonitor::Logs::Query.new(params: { search: "timeout" }).call

        assert_equal [ @older_fetch_entry.id ], result.entries.map(&:id)
      end

      test "paginates results using configured per_page" do
        30.times do |index|
          FeedMonitor::FetchLog.create!(
            source: @source_a,
            success: true,
            http_status: 200,
            items_created: 0,
            items_updated: 0,
            items_failed: 0,
            started_at: (index + 31).minutes.ago
          )
        end

        result_page_1 = FeedMonitor::Logs::Query.new(params: { page: 1, per_page: 25 }).call
        result_page_2 = FeedMonitor::Logs::Query.new(params: { page: 2, per_page: 25 }).call

        assert_equal 25, result_page_1.entries.count
        assert result_page_1.has_next_page?
        assert_not result_page_1.has_previous_page?

        assert result_page_2.entries.present?
        assert result_page_2.has_previous_page?
      end

      test "sanitizes invalid parameters without raising" do
        result = FeedMonitor::Logs::Query.new(
          params: {
            log_type: "<svg>",
            status: "failed<script>",
            source_id: "1; DROP TABLE fetch_logs;",
            timeframe: "bogus"
          }
        ).call

        assert_equal [ @recent_scrape_entry.id, @older_fetch_entry.id ],
                     result.entries.map(&:id)
      end
    end
  end
end
