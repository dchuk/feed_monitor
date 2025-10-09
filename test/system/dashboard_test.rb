# frozen_string_literal: true

require "application_system_test_case"

module FeedMonitor
  class DashboardTest < ApplicationSystemTestCase
    setup do
      FeedMonitor.reset_configuration!
      FeedMonitor::Jobs::Visibility.reset!
      FeedMonitor::Jobs::Visibility.setup!
    end

    teardown do
      FeedMonitor.reset_configuration!
      FeedMonitor::Jobs::Visibility.reset!
    end

    test "dashboard displays stats, job metrics, and quick actions" do
      FeedMonitor.configure do |config|
        config.mission_control_enabled = true
        config.mission_control_dashboard_path = -> { FeedMonitor::Engine.routes.url_helpers.root_path }
      end

      source = Source.create!(name: "Example", feed_url: "https://example.com/feed", next_fetch_at: 1.hour.from_now)
      Item.create!(source:, guid: "item-1", url: "https://example.com/item")
      FetchLog.create!(source:, success: true, items_created: 1, items_updated: 0, started_at: Time.current)
      ScrapeLog.create!(source:, item: source.items.first, success: false, scraper_adapter: "readability", started_at: 5.minutes.ago)

      visit feed_monitor.root_path

      assert_text "Overview"
      assert_text "Recent Activity"
      assert_text "Quick Actions"
      assert_text "Job Queues"

      within first(".rounded-lg", text: "Sources") do
        assert_text "1"
      end

      assert_selector "span", text: "Success"
      assert_selector "span", text: "Failure"
      assert_selector "a", text: "Go", count: 3

      adapter_label = FeedMonitor::Jobs::Visibility.adapter_name.to_s
      assert_text adapter_label
      assert_text FeedMonitor.queue_name(:fetch)
      assert_text FeedMonitor.queue_name(:scrape)
      assert_text "Depth: 0"
      assert_selector "a", text: "Open Mission Control"
    end
  end
end
