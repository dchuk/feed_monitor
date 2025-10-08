# frozen_string_literal: true

require "application_system_test_case"

module FeedMonitor
  class DashboardTest < ApplicationSystemTestCase
    test "dashboard displays stats and activity" do
      source = Source.create!(name: "Example", feed_url: "https://example.com/feed", next_fetch_at: 1.hour.from_now)
      Item.create!(source:, guid: "item-1", url: "https://example.com/item")
      FetchLog.create!(source:, success: true, items_created: 1, items_updated: 0, started_at: Time.current)
      ScrapeLog.create!(source:, item: source.items.first, success: false, scraper_adapter: "readability", started_at: 5.minutes.ago)

      visit feed_monitor.root_path

      assert_text "Overview"
      assert_text "Sources"
      assert_text "Recent Activity"
      assert_text "Quick Actions"

      within first(".rounded-lg", text: "Sources") do
        assert_text "1"
      end

      assert_selector "span", text: "Success"
      assert_selector "span", text: "Failure"
      assert_selector "a", text: "Go", count: 3
    end
  end
end
