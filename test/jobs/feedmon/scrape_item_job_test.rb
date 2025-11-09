# frozen_string_literal: true

require "test_helper"
require "securerandom"
require "minitest/mock"

module Feedmon
  class ScrapeItemJobTest < ActiveJob::TestCase
    test "performs scraping via item scraper and records a log" do
      source = create_source(scraping_enabled: true)
      item = create_item(source:)

      result = Feedmon::Scrapers::Base::Result.new(
        status: :success,
        html: "<article><p>Scraped HTML</p></article>",
        content: "Scraped body",
        metadata: { http_status: 200, extraction_strategy: "readability" }
      )

      Feedmon::Scrapers::Readability.stub(:call, result) do
        assert_difference("Feedmon::ScrapeLog.count", 1) do
          Feedmon::ScrapeItemJob.perform_now(item.id)
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

      assert_no_changes -> { Feedmon::ScrapeLog.count } do
        Feedmon::ScrapeItemJob.perform_now(item.id)
      end

      assert_nil item.reload.scrape_status
    end

    test "marks item failed and clears processing when scraper raises unexpectedly" do
      source = create_source(scraping_enabled: true)
      item = create_item(source:)

      fake_scraper = Class.new do
        def call
          raise StandardError, "boom"
        end
      end

      Feedmon::Scraping::ItemScraper.stub(:new, ->(**_args) { fake_scraper.new }) do
        assert_raises(StandardError) do
          Feedmon::ScrapeItemJob.perform_now(item.id)
        end
      end

      item.reload
      assert_equal "failed", item.scrape_status
      assert item.scraped_at.present?
    end

    private

    def create_source(scraping_enabled:)
      create_source!(
        scraping_enabled: scraping_enabled,
        auto_scrape: true
      )
    end

    def create_item(source:)
      Feedmon::Item.create!(
        source: source,
        guid: SecureRandom.uuid,
        url: "https://example.com/#{SecureRandom.hex}",
        title: "Example Item"
      )
    end
  end
end
