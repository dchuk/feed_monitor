require "test_helper"
require "securerandom"

module FeedMonitor
  class LogCleanupJobTest < ActiveJob::TestCase
    setup do
      FeedMonitor::FetchLog.delete_all
      FeedMonitor::ScrapeLog.delete_all
      FeedMonitor::Item.delete_all
      FeedMonitor::Source.delete_all
    end

    test "removes fetch and scrape logs older than the configured thresholds" do
      source = create_source
      item = create_item(source:)

      travel_to Time.zone.local(2025, 7, 1, 8, 0, 0) do
        create_fetch_log(source:, label: "old")
        create_scrape_log(source:, item:, label: "old")
      end

      travel_to Time.zone.local(2025, 9, 15, 10, 0, 0) do
        create_fetch_log(source:, label: "recent")
        create_scrape_log(source:, item:, label: "recent")

        FeedMonitor::LogCleanupJob.perform_now(
          now: Time.current,
          fetch_logs_older_than_days: 60,
          scrape_logs_older_than_days: 60
        )

        assert_equal ["recent"], FeedMonitor::FetchLog.order(:created_at).pluck(Arel.sql("metadata->>'label'"))
        assert_equal ["recent"], FeedMonitor::ScrapeLog.order(:created_at).pluck(Arel.sql("metadata->>'label'"))
      end
    end

    test "skips cleanup when negative thresholds provided" do
      source = create_source
      item = create_item(source:)

      travel_to Time.zone.local(2025, 6, 1, 12, 0, 0) do
        create_fetch_log(source:, label: "old")
        create_scrape_log(source:, item:, label: "old")
      end

      travel_to Time.zone.local(2025, 10, 10, 12, 0, 0) do
        FeedMonitor::LogCleanupJob.perform_now(
          now: Time.current,
          fetch_logs_older_than_days: -1,
          scrape_logs_older_than_days: 0
        )

        assert_equal 1, FeedMonitor::FetchLog.count
        assert_equal 1, FeedMonitor::ScrapeLog.count
      end
    end

    private

    def create_source
      create_source!(
        name: "Source #{SecureRandom.hex(4)}",
        feed_url: "https://example.com/#{SecureRandom.hex(8)}.xml"
      )
    end

    def create_item(source:)
      source.items.create!(
        guid: SecureRandom.uuid,
        url: "https://example.com/items/#{SecureRandom.hex(6)}",
        title: "Test Item",
        published_at: Time.current,
        summary: "Summary"
      )
    end

    def create_fetch_log(source:, label:)
      FeedMonitor::FetchLog.create!(
        source: source,
        started_at: Time.current,
        success: true,
        items_created: 0,
        items_updated: 0,
        items_failed: 0,
        metadata: { "label" => label }
      )
    end

    def create_scrape_log(source:, item:, label:)
      FeedMonitor::ScrapeLog.create!(
        source: source,
        item: item,
        started_at: Time.current,
        success: true,
        scraper_adapter: "readability",
        metadata: { "label" => label }
      )
    end
  end
end
