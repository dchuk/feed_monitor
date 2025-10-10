# frozen_string_literal: true

require "application_system_test_case"

module FeedMonitor
  class SourcesTest < ApplicationSystemTestCase
    include ActiveJob::TestHelper

    setup do
      clear_enqueued_jobs
    end

    teardown do
      clear_enqueued_jobs
    end
    test "managing a source end to end" do
      visit feed_monitor.sources_path

      assert_selector "th", text: "New Items / Day"
      assert_selector "[data-testid='fetch-interval-heatmap']"

      assert_difference("FeedMonitor::Source.count", 1) do
        click_link "New Source", match: :first

        fill_in "Name", with: "UI Source"
        fill_in "Feed url", with: "https://example.com/feed"
        fill_in "Website url", with: "https://example.com"
        fill_in "Fetch interval (minutes)", with: "240"
        fill_in "Retention window (days)", with: "14"
        fill_in "Maximum stored items", with: "200"
        select "Readability", from: "Scraper adapter"

        click_button "Create Source"
      end

      assert_current_path feed_monitor.source_path(FeedMonitor::Source.last)
      assert_text "Source created successfully"
      assert_text "Retention Policy Active"

      source = FeedMonitor::Source.last

      FeedMonitor::Item.create!(
        source: source,
        guid: "ui-item-1",
        title: "UI Item Article",
        url: "https://example.com/articles/ui",
        summary: "Monitoring summary for UI validations.",
        scrape_status: "success",
        published_at: Time.current
      )

      visit feed_monitor.source_path(source)

      assert_selector "[data-testid='source-items-table']"
      assert_text "UI Item Article"

      click_link "Edit"
      fill_in "Name", with: "Updated Source"
      uncheck "Active"
      click_button "Update Source"

      assert_current_path feed_monitor.source_path(source)
      assert_text "Source updated successfully"
      assert_text "Updated Source"

      click_link "Sources"
      assert_current_path feed_monitor.sources_path
      assert_text "Updated Source"
      assert_selector "span", text: "Paused"
      within find("tr", text: "Updated Source") do
        assert_selector "td", text: %r{/ day}
      end

      assert_difference("FeedMonitor::Source.count", -1) do
        visit feed_monitor.source_path(source)
        click_button "Delete"
      end

      assert_current_path feed_monitor.sources_path
      assert_text "Source deleted"
      assert_no_text "Updated Source"
    end

    test "manually fetching a source" do
      FeedMonitor::Item.delete_all
      FeedMonitor::Source.delete_all

      source = FeedMonitor::Source.create!(
        name: "Fetchable Source",
        feed_url: "https://www.ruby-lang.org/en/feeds/news.rss",
        website_url: "https://example.com",
        fetch_interval_minutes: 60,
        scraper_adapter: "readability"
      )

      visit feed_monitor.source_path(source)

      assert_enqueued_with(job: FeedMonitor::FetchFeedJob, args: [source.id]) do
        click_button "Fetch Now"
      end

      assert_text "Fetch has been enqueued and will run shortly."

      VCR.use_cassette("feed_monitor/fetching/rss_success") do
        perform_enqueued_jobs
      end

      visit feed_monitor.source_path(source)

      assert_selector "[data-testid='source-items-table'] tbody tr", minimum: 1

      source.reload
      assert source.items_count.positive?, "expected items_count to increase"

      log = source.fetch_logs.order(:created_at).last
      total_processed = log.items_created + log.items_updated
      assert_equal source.items_count, total_processed
      assert_equal 0, log.items_failed
    end
  end
end
