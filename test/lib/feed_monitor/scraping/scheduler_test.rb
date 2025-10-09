# frozen_string_literal: true

require "test_helper"
require "securerandom"

module FeedMonitor
  module Scraping
    class SchedulerTest < ActiveSupport::TestCase
      include ActiveJob::TestHelper

      setup do
        ActiveJob::Base.queue_adapter = :test
        clear_enqueued_jobs
        FeedMonitor::ScrapeLog.delete_all
        FeedMonitor::Item.delete_all
        FeedMonitor::Source.delete_all
      end

      teardown do
        clear_enqueued_jobs
      end

      test "enqueues scraping jobs for auto-scrape sources" do
        source = create_source(scraping_enabled: true, auto_scrape: true)
        item_one = create_item(source:)
        item_two = create_item(source:)

        # Should ignore sources without auto-scrape
        other_source = create_source(scraping_enabled: true, auto_scrape: false)
        _ignored_item = create_item(source: other_source)

        assert_difference -> { enqueued_jobs.size }, 2 do
          FeedMonitor::Scraping::Scheduler.run(limit: 10)
        end

        assert_enqueued_with(job: FeedMonitor::ScrapeItemJob, args: [item_one.id])
        assert_enqueued_with(job: FeedMonitor::ScrapeItemJob, args: [item_two.id])
      end

      test "respects the provided limit" do
        source = create_source(scraping_enabled: true, auto_scrape: true)
        first_item = create_item(source:)
        _second_item = create_item(source:)

        assert_difference -> { enqueued_jobs.size }, 1 do
          FeedMonitor::Scraping::Scheduler.run(limit: 1)
        end

        assert_enqueued_with(job: FeedMonitor::ScrapeItemJob, args: [first_item.id])
      end

      private

      def create_source(scraping_enabled:, auto_scrape:)
        FeedMonitor::Source.create!(
          name: "Source #{SecureRandom.hex(4)}",
          feed_url: "https://example.com/#{SecureRandom.hex(8)}.xml",
          website_url: "https://example.com",
          fetch_interval_minutes: 60,
          scraping_enabled: scraping_enabled,
          auto_scrape: auto_scrape
        )
      end

      def create_item(source:)
        FeedMonitor::Item.create!(
          source: source,
          guid: SecureRandom.uuid,
          url: "https://example.com/#{SecureRandom.hex(8)}",
          title: "Item #{SecureRandom.hex(4)}"
        )
      end
    end
  end
end
