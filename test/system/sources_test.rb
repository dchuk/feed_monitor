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

      click_link "New Source", match: :first

      fill_in "Name", with: "UI Source"
      fill_in "Feed url", with: "https://example.com/feed"
      fill_in "Website url", with: "https://example.com"
      fill_in "Fetch interval (minutes)", with: "240"
      fill_in "Retention window (days)", with: "14"
      fill_in "Maximum stored items", with: "200"
      select "Readability", from: "Scraper adapter"

      click_button "Create Source"
      assert_selector "h1", text: "UI Source"
      source = FeedMonitor::Source.find_by!(feed_url: "https://example.com/feed")
      assert_equal "UI Source", source.name
      assert_current_path feed_monitor.source_path(FeedMonitor::Source.last)
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
      assert_text "Updated Source"

      click_link "Sources"
      assert_current_path feed_monitor.sources_path
      assert_text "Updated Source"
      assert_selector "span", text: "Paused"
      within find("tr", text: "Updated Source") do
        assert_selector "td", text: %r{/ day}
      end

      visit feed_monitor.source_path(source)
      accept_confirm do
        click_button "Delete"
      end
      assert_no_text "Updated Source"
      refute FeedMonitor::Source.exists?(source.id)

      assert_current_path feed_monitor.sources_path
      assert_no_text "Updated Source"
    end

    test "searching sources filters the list" do
      create_source!(name: "Ruby Updates", feed_url: "https://ruby.example.com/feed.xml")
      create_source!(name: "Elixir News", feed_url: "https://elixir.example.com/feed.xml")

      visit feed_monitor.sources_path

      assert_text "Ruby Updates"
      assert_text "Elixir News"

      fill_in "Search sources", with: "Ruby"
      click_button "Search"

      assert_text "Ruby Updates"
      assert_no_text "Elixir News"
      assert_text "Showing results for"

      click_link "Clear search"

      assert_text "Ruby Updates"
      assert_text "Elixir News"
    end

    test "filtering sources via fetch interval heatmap" do
      create_source!(name: "Quick Source", fetch_interval_minutes: 15, feed_url: "https://quick.example.com/feed.xml")
      create_source!(name: "Regular Source", fetch_interval_minutes: 45, feed_url: "https://regular.example.com/feed.xml")
      create_source!(name: "Slow Source", fetch_interval_minutes: 95, feed_url: "https://slow.example.com/feed.xml")

      visit feed_monitor.sources_path

      find("[data-testid='fetch-interval-bucket-30-60']").click

      assert_text "Filtered by fetch interval"
      assert_text "Regular Source"
      assert_no_text "Quick Source"
      assert_no_text "Slow Source"

      click_link "Clear interval filter"

      assert_text "Quick Source"
      assert_text "Regular Source"
      assert_text "Slow Source"
    end

    test "manually fetching a source" do
      FeedMonitor::Item.delete_all
      FeedMonitor::Source.delete_all

      source = create_source!(
        name: "Fetchable Source",
        feed_url: "https://www.ruby-lang.org/en/feeds/news.rss"
      )

      visit feed_monitor.source_path(source)

      click_button "Fetch Now"
      assert_selector "[data-testid='fetch-status-badge']", text: "Queued"

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
