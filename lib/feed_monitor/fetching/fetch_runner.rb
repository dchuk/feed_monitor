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

      def self.enqueue(source_or_id)
        source = resolve_source(source_or_id)
        return unless source

        # Don't broadcast here - controller handles immediate UI update
        source.update!(fetch_status: "queued")
        FeedMonitor::FetchFeedJob.perform_later(source.id)
      end

      def run
        result = nil

        with_concurrency_guard do
          mark_fetching!
          result = fetcher_class.new(source: source).call
          apply_retention
          enqueue_follow_up_scrapes(result)
          mark_complete!(result)
        end

        FeedMonitor::Events.after_fetch_completed(source: source, result: result)
        result
      rescue StandardError => error
        mark_failed!(error)
        FeedMonitor::Events.after_fetch_completed(source: source, result: nil)
        raise
      end

      private

      def self.resolve_source(source_or_id)
        return source_or_id if source_or_id.is_a?(FeedMonitor::Source)

        FeedMonitor::Source.find_by(id: source_or_id)
      end
      private_class_method :resolve_source

      def self.update_source_state!(source, attrs)
        source.update!(attrs)
        FeedMonitor::Realtime.broadcast_source(source)
      rescue StandardError => error
        Rails.logger.error(
          "[FeedMonitor] Failed to update fetch state for source #{source.id}: #{error.class}: #{error.message}"
        ) if defined?(Rails) && Rails.respond_to?(:logger) && Rails.logger
      end
      private_class_method :update_source_state!

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

      def mark_fetching!
        update_source_state(fetch_status: "fetching", last_fetch_started_at: Time.current)
      end

      def mark_complete!(result)
        status = result&.status
        new_status = status == :failed ? "failed" : "idle"
        update_source_state(fetch_status: new_status)
      end

      def mark_failed!(_error)
        update_source_state(fetch_status: "failed")
      end

      def update_source_state(attrs)
        self.class.send(:update_source_state!, source, attrs)
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
