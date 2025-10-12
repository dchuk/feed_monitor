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
      source = create_source!(name: "Example Source")

      first_item = FeedMonitor::Item.create!(
        source: source,
        guid: "item-1",
        title: "First Article",
        url: "https://example.com/articles/1",
        summary: "Short summary about the first article.",
        content: "Full content body for the first article.",
        scraped_html: "<article><p>Scraped HTML</p></article>",
        scraped_content: "Scraped plain text content.",
        categories: %w[engineering performance],
        tags: %w[ruby rails],
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

      assert_item_order ["First Article", "Second Post"]

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
      within(:xpath, "//div[contains(@class,'rounded-lg')][.//h2[text()='Item Details']]") do
        assert_text "engineering, performance"
        assert_text "ruby, rails"
      end
      within(:xpath, "//div[contains(@class,'rounded-lg')][.//h2[text()='Counts & Metrics']]") do
        refute_text "engineering, performance"
        refute_text "ruby, rails"
      end
    end

    test "manually scraping an item updates content and records a log" do
      source = create_source!(name: "Manual Source", scraping_enabled: true)

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

      FeedMonitor::Scrapers::Readability.stub(:call, result) do
        click_button "Manual Scrape"
        assert_selector "[data-testid='scrape-status-badge']", text: "Pending", wait: 5

        assert_difference("FeedMonitor::ScrapeLog.count", 1) do
          perform_enqueued_jobs
        end
      end
      item.reload
      assert_equal "success", item.scrape_status
      visit feed_monitor.item_path(item)
      assert_selector "[data-testid='scrape-status-badge']", text: "Scraped", wait: 10
      assert_text "Readable body text"
      find("summary", text: "View raw HTML").click
      assert_text "Rendered HTML"
    end

    test "items table supports sorting" do
      FeedMonitor::Item.delete_all
      source = create_source!(name: "Sorted Source")

      older = FeedMonitor::Item.create!(
        source: source,
        guid: "item-old",
        title: "Older Item",
        url: "https://example.com/items/old",
        published_at: 2.days.ago
      )
      newer = FeedMonitor::Item.create!(
        source: source,
        guid: "item-new",
        title: "Newer Item",
        url: "https://example.com/items/new",
        published_at: 1.hour.ago
      )

      visit feed_monitor.items_path

      assert_item_order ["Newer Item", "Older Item"]
      within "turbo-frame#feed_monitor_items_table thead th[data-sort-column='published_at']" do
        assert_text "▼"
      end

      within "turbo-frame#feed_monitor_items_table thead" do
        click_link "Published"
      end
      assert_item_order ["Older Item", "Newer Item"]
      within "turbo-frame#feed_monitor_items_table thead th[data-sort-column='published_at']" do
        assert_text "▲"
      end

      within "turbo-frame#feed_monitor_items_table thead" do
        click_link "Published"
      end
      assert_item_order ["Newer Item", "Older Item"]
      within "turbo-frame#feed_monitor_items_table thead th[data-sort-column='published_at']" do
        assert_text "▼"
      end
    end

    private

    def assert_item_order(expected)
      within "turbo-frame#feed_monitor_items_table" do
        expected.each_with_index do |title, index|
          assert_selector :xpath,
            format(".//tbody/tr[%<row>d]/td[1]", row: index + 1),
            text: /\A#{Regexp.escape(title)}/
        end
      end
    end
  end
end
