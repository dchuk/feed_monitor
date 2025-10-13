# frozen_string_literal: true

require "test_helper"

module FeedMonitor
  module Scraping
    class BulkSourceScraperTest < ActiveSupport::TestCase
      include ActiveJob::TestHelper

      setup do
        ActiveJob::Base.queue_adapter = :test
        clear_enqueued_jobs
      end

      teardown do
        clear_enqueued_jobs
      end

      test "enqueues scraping for current items preview" do
        source = create_source!(scraping_enabled: true)
        recent_items = Array.new(3) { create_item!(source:, published_at: Time.current) }

        result = nil

        assert_enqueued_jobs 3 do
          result = FeedMonitor::Scraping::BulkSourceScraper.new(
            source:,
            selection: :current,
            preview_limit: 10
          ).call
        end

        assert_equal :success, result.status
        assert_equal 3, result.enqueued_count
        assert_equal 3, result.attempted_count
        assert_equal 0, result.already_enqueued_count
        assert_equal 0, result.failure_count
        recent_items.each do |item|
          assert_equal "pending", item.reload.scrape_status
        end
      end

      test "scrapes only unscraped items when selection is :unscraped" do
        source = create_source!(scraping_enabled: true)
        scraped = create_item!(source:, scrape_status: "success", scraped_at: 1.day.ago)
        pending = create_item!(source:, scrape_status: nil, scraped_at: nil)
        never_scraped = create_item!(source:, scrape_status: nil, scraped_at: nil)

        result = FeedMonitor::Scraping::BulkSourceScraper.new(
          source:,
          selection: :unscraped,
          preview_limit: 10
        ).call

        assert_equal :success, result.status
        assert_equal 2, result.enqueued_count
        assert_equal 2, result.attempted_count
        assert_equal 0, result.failure_count
        assert_equal "pending", pending.reload.scrape_status
        assert_equal "pending", never_scraped.reload.scrape_status
        assert_equal "success", scraped.reload.scrape_status
      end

      test "returns error result when no items match selection" do
        source = create_source!(scraping_enabled: true)

        result = FeedMonitor::Scraping::BulkSourceScraper.new(
          source:,
          selection: :unscraped,
          preview_limit: 10
        ).call

        assert_equal :error, result.status
        assert_equal 0, result.enqueued_count
        assert_equal 0, result.attempted_count
        assert_equal({ no_items: 1 }, result.failure_details)
      end

      test "respects per-source rate limit" do
        source = create_source!(scraping_enabled: true)
        create_item!(source:, scrape_status: "pending")
        eligible = Array.new(3) { create_item!(source:, scrape_status: nil, scraped_at: nil) }

        FeedMonitor.configure do |config|
          config.scraping.max_in_flight_per_source = 2
        end

        result = FeedMonitor::Scraping::BulkSourceScraper.new(
          source:,
          selection: :all,
          preview_limit: 10
        ).call

        assert_equal :partial, result.status
        assert_equal 1, result.enqueued_count
        assert_equal 3, result.attempted_count
        assert_equal 1, result.failure_details[:rate_limited]
        assert result.rate_limited?
        statuses = eligible.map { |item| item.reload.scrape_status }
        assert_includes statuses, "pending"
        statuses.each_with_index do |status, index|
          next if status == "pending"

          assert_nil status, "expected item #{eligible[index].id} to remain unqueued"
        end
      end

      test "selection counts ignore association cache limits" do
        source = create_source!(scraping_enabled: true)
        12.times do
          create_item!(
            source:,
            scrape_status: nil,
            scraped_at: nil,
            published_at: Time.current
          )
        end

        cached_preview = source.items.recent.limit(5).to_a
        assert_equal 5, cached_preview.size

        counts = FeedMonitor::Scraping::BulkSourceScraper.selection_counts(
          source:,
          preview_items: cached_preview,
          preview_limit: 10
        )

        assert_equal 5, counts[:current]
        assert_equal 12, counts[:all]
      end

      private

      def create_item!(source:, **attrs)
        FeedMonitor::Item.create!(
          {
            source:,
            guid: SecureRandom.uuid,
            url: "https://example.com/#{SecureRandom.hex(6)}",
            title: "Example Item"
          }.merge(attrs)
        )
      end
    end
  end
end
