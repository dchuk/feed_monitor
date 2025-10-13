# frozen_string_literal: true

require "test_helper"
require "securerandom"

module FeedMonitor
  module Scraping
    class EnqueuerTest < ActiveSupport::TestCase
      include ActiveJob::TestHelper

      setup do
        clear_enqueued_jobs
        FeedMonitor::ScrapeLog.delete_all
        FeedMonitor::Item.delete_all
        FeedMonitor::Source.delete_all
      end

      test "enqueues scrape job and marks item pending" do
        source = create_source(scraping_enabled: true)
        item = create_item(source:)

        result = nil

        assert_enqueued_with(job: FeedMonitor::ScrapeItemJob, args: [ item.id ]) do
          result = Enqueuer.enqueue(item: item, reason: :manual)
        end

        assert result.enqueued?, "expected enqueue result to signal success"
        assert_equal "pending", item.reload.scrape_status
      end

      test "does not enqueue when scraping is disabled" do
        source = create_source(scraping_enabled: false)
        item = create_item(source:)

        result = Enqueuer.enqueue(item: item, reason: :manual)

        assert result.failure?
        assert_equal :scraping_disabled, result.status
        assert_equal "Scraping is disabled for this source.", result.message
        assert_enqueued_jobs 0
        assert_nil item.reload.scrape_status
      end

      test "deduplicates when item already pending or processing" do
        source = create_source(scraping_enabled: true)
        item = create_item(source:, scrape_status: "pending")

        result = Enqueuer.enqueue(item: item, reason: :manual)

        assert result.already_enqueued?, "expected deduplication to report already enqueued"
        assert_equal "Scrape already in progress for this item.", result.message
        assert_enqueued_jobs 0

        item.update!(scrape_status: "processing")
        second_result = Enqueuer.enqueue(item: item, reason: :manual)

        assert second_result.already_enqueued?
        assert_enqueued_jobs 0
      end

      test "respects automatic scraping configuration" do
        source = create_source(scraping_enabled: true, auto_scrape: false)
        item = create_item(source:)

        result = Enqueuer.enqueue(item: item, reason: :auto)

        assert result.failure?
        assert_equal :auto_scrape_disabled, result.status
        assert_enqueued_jobs 0
      end

      private

      def create_source(scraping_enabled:, auto_scrape: false)
        create_source!(
          scraping_enabled: scraping_enabled,
          auto_scrape: auto_scrape
        )
      end

      def create_item(source:, scrape_status: nil)
        FeedMonitor::Item.create!(
          source: source,
          guid: SecureRandom.uuid,
          url: "https://example.com/#{SecureRandom.hex}",
          title: "Example Item",
          scrape_status: scrape_status
        )
      end
    end
  end
end
