require "test_helper"
require "securerandom"
require "minitest/mock"

module FeedMonitor
  module Fetching
    class FetchRunnerTest < ActiveSupport::TestCase
      include ActiveJob::TestHelper

      setup do
        clear_enqueued_jobs
        FeedMonitor::FetchLog.delete_all
        FeedMonitor::Item.delete_all
        FeedMonitor::Source.delete_all
      end

      test "enqueues scrape jobs for newly created items when auto scrape is enabled" do
        source = create_source(scraping_enabled: true, auto_scrape: true)
        item = FeedMonitor::Item.create!(
          source: source,
          guid: SecureRandom.uuid,
          url: "https://example.com/#{SecureRandom.hex}",
          title: "Example item"
        )

        processing = FeedMonitor::Fetching::FeedFetcher::EntryProcessingResult.new(
          created: 1,
          updated: 0,
          failed: 0,
          items: [item],
          errors: [],
          created_items: [item],
          updated_items: []
        )
        result = FeedMonitor::Fetching::FeedFetcher::Result.new(
          status: :fetched,
          feed: nil,
          response: nil,
          body: nil,
          item_processing: processing
        )

        stub_fetcher = Class.new do
          define_method(:initialize) { |**_kwargs| }
          define_method(:call) { result }
        end

        assert_enqueued_with(job: FeedMonitor::ScrapeItemJob, args: [item.id]) do
          FetchRunner.new(source:, fetcher_class: stub_fetcher).run
        end

        assert_equal "pending", item.reload.scrape_status
      end

      test "enqueue marks source as queued" do
        source = create_source

        FeedMonitor::Realtime.stub :broadcast_source, nil do
          FeedMonitor::FetchFeedJob.stub :perform_later, nil do
            FetchRunner.enqueue(source.id)
          end
        end

        assert_equal "queued", source.reload.fetch_status
      end

      test "run updates fetch status lifecycle for successful fetch" do
        source = create_source

        stub_fetcher = Class.new do
          define_method(:initialize) { |**_kwargs| }

          define_method(:call) do
            FeedMonitor::Fetching::FeedFetcher::Result.new(status: :fetched)
          end
        end

        FeedMonitor::Realtime.stub :broadcast_source, nil do
          FetchRunner.new(source:, fetcher_class: stub_fetcher).run
        end

        source.reload
        assert_equal "idle", source.fetch_status
        assert_not_nil source.last_fetch_started_at
      end

      test "run marks source as failed when fetcher raises" do
        source = create_source

        failing_fetcher = Class.new do
          define_method(:initialize) { |**_kwargs| }
          define_method(:call) { raise StandardError, "boom" }
        end

        FeedMonitor::Realtime.stub :broadcast_source, nil do
          assert_raises(StandardError) do
            FetchRunner.new(source:, fetcher_class: failing_fetcher).run
          end
        end

        assert_equal "failed", source.reload.fetch_status
      end

      test "does not enqueue scrape jobs when auto scrape is disabled" do
        source = create_source(scraping_enabled: true, auto_scrape: false)
        item = FeedMonitor::Item.create!(
          source: source,
          guid: SecureRandom.uuid,
          url: "https://example.com/#{SecureRandom.hex}",
          title: "Example item"
        )

        processing = FeedMonitor::Fetching::FeedFetcher::EntryProcessingResult.new(
          created: 1,
          updated: 0,
          failed: 0,
          items: [item],
          errors: [],
          created_items: [item],
          updated_items: []
        )
        result = FeedMonitor::Fetching::FeedFetcher::Result.new(
          status: :fetched,
          feed: nil,
          response: nil,
          body: nil,
          item_processing: processing
        )

        stub_fetcher = Class.new do
          define_method(:initialize) { |**_kwargs| }
          define_method(:call) { result }
        end

        assert_no_enqueued_jobs only: FeedMonitor::ScrapeItemJob do
          FetchRunner.new(source:, fetcher_class: stub_fetcher).run
        end

        assert_nil item.reload.scrape_status
      end

      test "raises concurrency error when advisory lock acquisition fails" do
        source = create_source
        runner = FetchRunner.new(source:, fetcher_class: DummyFetcher)

        runner.singleton_class.class_eval do
          define_method(:try_lock) { |_connection| false }
        end

        assert_raises(FetchRunner::ConcurrencyError) { runner.run }
      end

      test "invokes retention pruner after each fetch run" do
        source = create_source

        stub_fetcher = Class.new do
          define_method(:initialize) { |**_kwargs| }

          define_method(:call) do
            FeedMonitor::Fetching::FeedFetcher::Result.new(status: :not_modified)
          end
        end

        retention_spy = Class.new do
          class << self
            attr_accessor :calls
          end

          def self.call(source:, **)
            self.calls ||= []
            self.calls << source
            nil
          end
        end
        retention_spy.calls = []

        FetchRunner.new(
          source:,
          fetcher_class: stub_fetcher,
          retention_pruner_class: retention_spy
        ).run

        assert_equal [source], retention_spy.calls
      end

      private

      def create_source(scraping_enabled: false, auto_scrape: false)
        create_source!(
          scraping_enabled: scraping_enabled,
          auto_scrape: auto_scrape
        )
      end

      class DummyFetcher
        def initialize(*); end

        def call
          FeedMonitor::Fetching::FeedFetcher::Result.new(status: :not_modified)
        end
      end
    end
  end
end
