# frozen_string_literal: true

require "application_system_test_case"

module Feedmon
  class LogsTest < ApplicationSystemTestCase
    setup do
      @source = create_source!(name: "Log Source", fetch_interval_minutes: 360)

      @item = Feedmon::Item.create!(
        source: @source,
        guid: "log-item-1",
        title: "Log Item",
        url: "https://example.com/articles/log-item",
        scrape_status: "pending",
        published_at: Time.current
      )

      @success_fetch_log = Feedmon::FetchLog.create!(
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

      @failure_fetch_log = Feedmon::FetchLog.create!(
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

      @success_scrape_log = Feedmon::ScrapeLog.create!(
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

      @failure_scrape_log = Feedmon::ScrapeLog.create!(
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

    test "filtering consolidated logs by type and status" do
      visit feedmon.logs_path

      assert_text "Logs"
      assert_selector "[data-log-row='fetch-#{@success_fetch_log.id}']"
      assert_selector "[data-log-row='scrape-#{@failure_scrape_log.id}']"

      click_link "Scrape Logs"
      assert_selector "[data-log-row='scrape-#{@success_scrape_log.id}']"
      assert_no_selector "[data-log-row='fetch-#{@success_fetch_log.id}']"

      click_link "Failures"
      assert_selector "[data-log-row='scrape-#{@failure_scrape_log.id}']"
      assert_no_selector "[data-log-row='scrape-#{@success_scrape_log.id}']"

      click_link "View Details", match: :first
      assert_text "Scrape Log"
      assert_current_path feedmon.scrape_log_path(@failure_scrape_log)
    end

    test "searching logs and paging through results" do
      40.times do |index|
        Feedmon::FetchLog.create!(
          source: @source,
          success: false,
          http_status: 500,
          items_created: 0,
          items_updated: 0,
          items_failed: 0,
          error_message: "Batch failure #{index}",
          started_at: Time.current - (index + 3).hours
        )
      end

      visit feedmon.logs_path

      fill_in "Search logs", with: "Batch failure 3"
      click_button "Search"
      assert_text "Batch failure 3"
      assert_no_text "Batch failure 15"

      click_link "Clear"

      click_link "Next"
      assert_selector "[data-page-indicator='2']"

      click_link "Previous"
      assert_selector "[data-page-indicator='1']"
    end
  end
end
