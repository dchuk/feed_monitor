# frozen_string_literal: true

require "application_system_test_case"
require "minitest/mock"

module FeedMonitor
  class ItemsTest < ApplicationSystemTestCase
    include ActiveJob::TestHelper

    setup do
      clear_enqueued_jobs
    end

    teardown do
      clear_enqueued_jobs
    end
    test "browsing items and viewing item details" do
      source = FeedMonitor::Source.create!(
        name: "Example Source",
        feed_url: "https://example.com/feed.xml",
        website_url: "https://example.com",
        fetch_interval_minutes: 360,
        scraper_adapter: "readability"
      )

      first_item = FeedMonitor::Item.create!(
        source: source,
        guid: "item-1",
        title: "First Article",
        url: "https://example.com/articles/1",
        summary: "Short summary about the first article.",
        content: "Full content body for the first article.",
        scraped_html: "<article><p>Scraped HTML</p></article>",
        scraped_content: "Scraped plain text content.",
        scrape_status: "success",
        scraped_at: Time.current,
        published_at: Time.current,
        metadata: { "word_count" => 450 }
      )

      FeedMonitor::Item.create!(
        source: source,
        guid: "item-2",
        title: "Second Post",
        url: "https://example.com/articles/2",
        scrape_status: "pending",
        published_at: Time.current - 1.day
      )

      visit feed_monitor.items_path

      assert_text "First Article"
      assert_text "Second Post"

      fill_in "Search items", with: "First"
      click_button "Search"

      assert_text "First Article"
      assert_no_text "Second Post"

      click_link "First Article"

      assert_current_path feed_monitor.item_path(first_item)
      assert_text "Feed Summary"
      assert_text "Short summary about the first article."
      assert_text "Feed Content"
      assert_text "Full content body for the first article."
      assert_text "Scraped Content"
      assert_text "Scraped plain text content."
      assert_text "View raw HTML"
      assert_text "word_count"
    end

    test "manually scraping an item updates content and records a log" do
      source = FeedMonitor::Source.create!(
        name: "Manual Source",
        feed_url: "https://example.com/manual.xml",
        website_url: "https://example.com",
        fetch_interval_minutes: 120,
        scraper_adapter: "readability",
        scraping_enabled: true
      )

      item = FeedMonitor::Item.create!(
        source: source,
        guid: "manual-1",
        title: "Needs Scraping",
        url: "https://example.com/articles/needs-scraping"
      )

      visit feed_monitor.item_path(item)

      result = FeedMonitor::Scrapers::Base::Result.new(
        status: :success,
        html: "<article><p>Rendered HTML</p></article>",
        content: "Readable body text",
        metadata: { http_status: 200, extraction_strategy: "readability" }
      )

      assert_difference("FeedMonitor::ScrapeLog.count", 1) do
        FeedMonitor::Scrapers::Readability.stub(:call, result) do
          perform_enqueued_jobs do
            click_button "Manual Scrape"
          end
        end
      end

      assert_text "Scrape has been enqueued and will run shortly."
      assert_text "Readable body text"
      find("summary", text: "View raw HTML").click
      assert_text "Rendered HTML"
      assert_text "Scraped"
    end
  end
end
