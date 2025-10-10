# frozen_string_literal: true

module FeedMonitor
  module Fetching
    # Coordinates execution of FeedFetcher while ensuring we do not run more than
    # one fetch per-source concurrently. The runner also centralizes the logic
    # for queuing follow-up scraping jobs so both background jobs and manual UI
    # entry points share the same behavior.
    class FetchRunner
      LOCK_NAMESPACE = 1_746_219

      class ConcurrencyError < StandardError; end

      attr_reader :source, :fetcher_class, :scrape_job_class, :scrape_enqueuer_class, :retention_pruner_class

      def initialize(source:, fetcher_class: FeedMonitor::Fetching::FeedFetcher, scrape_job_class: FeedMonitor::ScrapeItemJob, scrape_enqueuer_class: FeedMonitor::Scraping::Enqueuer, retention_pruner_class: FeedMonitor::Items::RetentionPruner)
        @source = source
        @fetcher_class = fetcher_class
        @scrape_job_class = scrape_job_class
        @scrape_enqueuer_class = scrape_enqueuer_class
        @retention_pruner_class = retention_pruner_class
      end

      def self.run(source:, **options)
        new(source:, **options).run
      end

      def self.enqueue(source_id)
        FeedMonitor::FetchFeedJob.perform_later(source_id)
      end

      def run
        with_concurrency_guard do
          result = fetcher_class.new(source: source).call
          apply_retention
          enqueue_follow_up_scrapes(result)
          FeedMonitor::Events.after_fetch_completed(source: source, result: result) if result
          result
        end
      end

      private

      def with_concurrency_guard
        ActiveRecord::Base.connection_pool.with_connection do |connection|
          locked = try_lock(connection)
          raise ConcurrencyError, "Fetch already in progress for source #{source.id}" unless locked

          begin
            yield
          ensure
            release_lock(connection)
          end
        end
      end

      def try_lock(connection)
        result = connection.exec_query("SELECT pg_try_advisory_lock(#{LOCK_NAMESPACE}, #{source.id})")
        value = result.rows.dig(0, 0)
        value == true || value.to_s == "t"
      end

      def release_lock(connection)
        connection.exec_query("SELECT pg_advisory_unlock(#{LOCK_NAMESPACE}, #{source.id})")
      rescue StandardError
        # If the connection has been reset or the lock already released, ignore
        # the error—Postgres automatically clears advisory locks when the
        # session terminates.
        nil
      end

      def enqueue_follow_up_scrapes(result)
        return unless should_enqueue_scrapes?(result)

        Array(result.item_processing&.created_items).each do |item|
          next unless scrape_needed?(item)

          scrape_enqueuer_class.enqueue(item:, source:, job_class: scrape_job_class, reason: :auto)
        end
      end

      def should_enqueue_scrapes?(result)
        return false unless result
        return false unless result.status == :fetched
        return false unless source.scraping_enabled? && source.auto_scrape?

        created_count = result.item_processing&.created.to_i
        created_count.positive?
      end

      def scrape_needed?(item)
        item.present? && item.scraped_at.nil?
      end

      def apply_retention
        retention_pruner_class.call(source:, strategy: FeedMonitor.config.retention.strategy)
      rescue StandardError => error
        Rails.logger.error(
          "[FeedMonitor] Retention pruning failed for source #{source.id}: #{error.class} - #{error.message}"
        )
      end
    end
  end
end
