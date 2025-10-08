# frozen_string_literal: true

require "application_system_test_case"

module FeedMonitor
  class ItemsTest < ApplicationSystemTestCase
    test "browsing items and viewing item details" do
      source = FeedMonitor::Source.create!(
        name: "Example Source",
        feed_url: "https://example.com/feed.xml",
        website_url: "https://example.com",
        fetch_interval_hours: 6,
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
      assert_text "Summary"
      assert_text "Short summary about the first article."
      assert_text "Feed Content"
      assert_text "Full content body for the first article."
      assert_text "Scraped HTML"
      assert_text "<article><p>Scraped HTML</p></article>"
      assert_text "Scraped Content"
      assert_text "Scraped plain text content."
      assert_text "word_count"
    end
  end
end
