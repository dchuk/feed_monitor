# frozen_string_literal: true

require "test_helper"
require "securerandom"
require "minitest/mock"

module FeedMonitor
  class ScrapeItemJobTest < ActiveJob::TestCase
    setup do
      FeedMonitor::ScrapeLog.delete_all
      FeedMonitor::Item.delete_all
      FeedMonitor::Source.delete_all
    end

    test "performs scraping via item scraper and records a log" do
      source = create_source(scraping_enabled: true)
      item = create_item(source:)

      result = FeedMonitor::Scrapers::Base::Result.new(
        status: :success,
        html: "<article><p>Scraped HTML</p></article>",
        content: "Scraped body",
        metadata: { http_status: 200, extraction_strategy: "readability" }
      )

      FeedMonitor::Scrapers::Readability.stub(:call, result) do
        assert_difference("FeedMonitor::ScrapeLog.count", 1) do
          FeedMonitor::ScrapeItemJob.perform_now(item.id)
        end
      end

      item.reload
      assert_equal "success", item.scrape_status
      assert_equal "Scraped body", item.scraped_content
      assert item.scraped_at.present?
    end

    test "skips scraping when the source has been disabled" do
      source = create_source(scraping_enabled: false)
      item = create_item(source:)

      assert_no_changes -> { FeedMonitor::ScrapeLog.count } do
        FeedMonitor::ScrapeItemJob.perform_now(item.id)
      end

      assert_nil item.reload.scrape_status
    end

    private

    def create_source(scraping_enabled:)
      FeedMonitor::Source.create!(
        name: "Example Source",
        feed_url: "https://example.com/feed.xml",
        website_url: "https://example.com",
        fetch_interval_minutes: 60,
        scraping_enabled: scraping_enabled,
        auto_scrape: true
      )
    end

    def create_item(source:)
      FeedMonitor::Item.create!(
        source: source,
        guid: SecureRandom.uuid,
        url: "https://example.com/#{SecureRandom.hex}",
        title: "Example Item"
      )
    end
  end
end
