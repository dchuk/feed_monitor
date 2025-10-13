# frozen_string_literal: true

require "test_helper"

module FeedMonitor
  class ApplicationHelperTest < ActionView::TestCase
    include FeedMonitor::ApplicationHelper

    test "source_health_badge returns healthy styling" do
      source = FeedMonitor::Source.new(health_status: "healthy")

      badge = source_health_badge(source)

      assert_equal "Healthy", badge[:label]
      assert_match(/green/, badge[:classes])
    end

    test "source_health_badge indicates auto paused" do
      source = FeedMonitor::Source.new(health_status: "auto_paused")

      badge = source_health_badge(source)

      assert_equal "Auto-Paused", badge[:label]
      assert_match(/amber|rose/, badge[:classes])
    end

    test "item_scrape_status_badge shows scraped label for success" do
      source = FeedMonitor::Source.new(scraping_enabled: true)
      item = FeedMonitor::Item.new(source:, guid: "status-success", url: "https://example.com/success", scrape_status: "success")

      badge = item_scrape_status_badge(item: item)

      assert_equal "success", badge[:status]
      assert_equal "Scraped", badge[:label]
      refute badge[:show_spinner]
      assert_match(/green/, badge[:classes])
    end

    test "item_scrape_status_badge shows pending spinner" do
      source = FeedMonitor::Source.new(scraping_enabled: true)
      item = FeedMonitor::Item.new(source:, guid: "status-pending", url: "https://example.com/pending", scrape_status: "pending")

      badge = item_scrape_status_badge(item: item)

      assert_equal "pending", badge[:status]
      assert_equal "Pending", badge[:label]
      assert badge[:show_spinner]
      assert_match(/amber|blue/, badge[:classes])
    end

    test "item_scrape_status_badge reports disabled when source scraping disabled" do
      source = FeedMonitor::Source.new(scraping_enabled: false)
      item = FeedMonitor::Item.new(source:, guid: "status-disabled", url: "https://example.com/disabled")

      badge = item_scrape_status_badge(item: item, source: source)

      assert_equal "disabled", badge[:status]
      assert_equal "Disabled", badge[:label]
      refute badge[:show_spinner]
      assert_match(/slate/, badge[:classes])
    end

    test "item_scrape_status_badge treats never scraped items as not scraped" do
      source = FeedMonitor::Source.new(scraping_enabled: true)
      item = FeedMonitor::Item.new(source:, guid: "status-never", url: "https://example.com/never")

      badge = item_scrape_status_badge(item: item, source: source)

      assert_equal "idle", badge[:status]
      assert_equal "Not scraped", badge[:label]
      refute badge[:show_spinner]
      assert_match(/slate/, badge[:classes])
    end
  end
end
