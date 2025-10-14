# frozen_string_literal: true

require "test_helper"

module FeedMonitor
  class SourceBulkScrapesControllerTest < ActionDispatch::IntegrationTest
    include ActionView::RecordIdentifier

    test "queues bulk scrape and renders turbo stream" do
      source = create_source!(scraping_enabled: true)
      result = FeedMonitor::Scraping::BulkSourceScraper::Result.new(
        status: :success,
        selection: :current,
        attempted_count: 2,
        enqueued_count: 2,
        already_enqueued_count: 0,
        failure_count: 0,
        failure_details: {},
        messages: ["Queued scraping for 2 items"],
        rate_limited: false
      )

      scraper = Minitest::Mock.new
      scraper.expect :call, result

      FeedMonitor::Scraping::BulkSourceScraper.stub(:new, ->(*) { scraper }) do
        post feed_monitor.source_bulk_scrape_path(source),
          params: { bulk_scrape: { selection: :current } },
          as: :turbo_stream
      end

      scraper.verify
      assert_response :success
      assert_equal "text/vnd.turbo-stream.html", response.media_type
      assert_includes response.body, "Queued scraping for 2 items"
      assert_includes response.body, %(<turbo-stream action="replace" target="#{dom_id(source, :row)}">)
    end

    test "returns unprocessable status when result indicates error" do
      source = create_source!(scraping_enabled: true)
      result = FeedMonitor::Scraping::BulkSourceScraper::Result.new(
        status: :error,
        selection: :current,
        attempted_count: 0,
        enqueued_count: 0,
        already_enqueued_count: 0,
        failure_count: 1,
        failure_details: { scraping_disabled: 1 },
        messages: ["Scraping is disabled"],
        rate_limited: false
      )

      scraper = Minitest::Mock.new
      scraper.expect :call, result

      FeedMonitor::Scraping::BulkSourceScraper.stub(:new, ->(*) { scraper }) do
        post feed_monitor.source_bulk_scrape_path(source),
          params: { bulk_scrape: { selection: :current } },
          as: :turbo_stream
      end

      scraper.verify
      assert_response :unprocessable_entity
      assert_includes response.body, "Scraping is disabled"
    end
  end
end
