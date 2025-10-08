# frozen_string_literal: true

require "application_system_test_case"

module FeedMonitor
  class LogsTest < ApplicationSystemTestCase
    setup do
      @source = FeedMonitor::Source.create!(
        name: "Log Source",
        feed_url: "https://example.com/feed.xml",
        website_url: "https://example.com",
        fetch_interval_minutes: 360,
        scraper_adapter: "readability"
      )

      @item = FeedMonitor::Item.create!(
        source: @source,
        guid: "log-item-1",
        title: "Log Item",
        url: "https://example.com/articles/log-item",
        scrape_status: "pending",
        published_at: Time.current
      )

      @success_fetch_log = FeedMonitor::FetchLog.create!(
        source: @source,
        success: true,
        started_at: Time.current - 2.hours,
        completed_at: Time.current - 2.hours + 5.seconds,
        http_status: 200,
        items_created: 3,
        items_updated: 1,
        items_failed: 0,
        duration_ms: 5000,
        metadata: { "etag" => "abc123" }
      )

      @failure_fetch_log = FeedMonitor::FetchLog.create!(
        source: @source,
        success: false,
        started_at: Time.current - 1.hour,
        completed_at: Time.current - 1.hour + 2.seconds,
        http_status: 500,
        items_created: 0,
        items_updated: 0,
        items_failed: 0,
        duration_ms: 2000,
        error_class: "TimeoutError",
        error_message: "execution expired"
      )

      @success_scrape_log = FeedMonitor::ScrapeLog.create!(
        source: @source,
        item: @item,
        success: true,
        scraper_adapter: "readability",
        started_at: Time.current - 90.minutes,
        completed_at: Time.current - 90.minutes + 1.second,
        http_status: 200,
        duration_ms: 1000,
        content_length: 12_345
      )

      @failure_scrape_log = FeedMonitor::ScrapeLog.create!(
        source: @source,
        item: @item,
        success: false,
        scraper_adapter: "readability",
        started_at: Time.current - 30.minutes,
        completed_at: Time.current - 30.minutes + 1.second,
        http_status: 500,
        duration_ms: 800,
        error_class: "RuntimeError",
        error_message: "failed to parse content"
      )
    end

    test "browsing fetch logs and viewing details" do
      visit feed_monitor.fetch_logs_path

      assert_selector "[data-testid='fetch-logs-table']"
      assert_text "Fetch Logs"
      assert_text @success_fetch_log.http_status.to_s
      assert_text @failure_fetch_log.http_status.to_s

      click_link "Failures"
      within "[data-testid='fetch-logs-table']" do
        assert_text @failure_fetch_log.http_status.to_s
        assert_no_text @success_fetch_log.http_status.to_s
      end

      click_link "View", match: :first
      assert_current_path feed_monitor.fetch_log_path(@failure_fetch_log)
      assert_text "TimeoutError"
      assert_text "execution expired"
      assert_text "Fetch Log"
    end

    test "browsing scrape logs and viewing details" do
      visit feed_monitor.scrape_logs_path

      assert_selector "[data-testid='scrape-logs-table']"
      assert_text "Scrape Logs"
      assert_text "Success"
      assert_text "Failure"

      click_link "Failures"
      within "[data-testid='scrape-logs-table']" do
        assert_text "Failure"
        assert_no_text "Success"
      end

      click_link "View", match: :first
      assert_current_path feed_monitor.scrape_log_path(@failure_scrape_log)
      assert_text "RuntimeError"
      assert_text "failed to parse content"
      assert_text "Scrape Log"
    end
  end
end
