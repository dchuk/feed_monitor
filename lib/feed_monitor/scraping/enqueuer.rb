# frozen_string_literal: true

module FeedMonitor
  module Scraping
    # Coordinates queuing of scraping jobs while respecting source
    # configuration and avoiding duplicate enqueues for the same item.
    class Enqueuer
      Result = Struct.new(:status, :message, :item, keyword_init: true) do
        def enqueued?
          status == :enqueued
        end

        def already_enqueued?
          status == :already_enqueued
        end

        def failure?
          !enqueued? && !already_enqueued?
        end
      end

      IN_FLIGHT_STATUSES = %w[pending processing].freeze

      attr_reader :item, :source, :job_class, :reason

      def self.enqueue(item:, source: nil, job_class: FeedMonitor::ScrapeItemJob, reason: :manual)
        new(item:, source:, job_class:, reason:).enqueue
      end

      def initialize(item:, source: nil, job_class: FeedMonitor::ScrapeItemJob, reason: :manual)
        @item = item
        @source = source || item&.source
        @job_class = job_class
        @reason = reason.to_sym
      end

      def enqueue
        log("enqueue:start", item:, source:, reason: reason)
        return failure(:missing_item, "Item could not be found.") unless item
        return failure(:missing_source, "Item must belong to a source.") unless source
        return failure(:scraping_disabled, "Scraping is disabled for this source.") unless source.scraping_enabled?
        if auto_reason? && !source.auto_scrape?
          return failure(:auto_scrape_disabled, "Automatic scraping is disabled for this source.")
        end

        already_queued = false

        item.with_lock do
          item.reload

          if in_flight?(item.scrape_status)
            log("enqueue:in_flight", item:, status: item.scrape_status)
            already_queued = true
            next
          end

          mark_pending!
        end

        if already_queued
          log("enqueue:already_enqueued", item:, status: item.scrape_status)
          return Result.new(status: :already_enqueued, message: "Scrape already in progress for this item.", item: item)
        end

        job_class.perform_later(item.id)
        log("enqueue:job_enqueued", item:, job_class: job_class.name)
        Result.new(status: :enqueued, message: "Scrape has been enqueued for processing.", item: item)
      end

      private

      def auto_reason?
        reason == :auto
      end

      def in_flight?(status)
        IN_FLIGHT_STATUSES.include?(status.to_s)
      end

      def mark_pending!
        item.update_columns(scrape_status: "pending") # rubocop:disable Rails/SkipsModelValidations
        log("enqueue:mark_pending", item:, status: item.scrape_status)
        # Don't broadcast here - the controller handles the immediate UI update
      end

      def failure(status, message)
        log("enqueue:failure", item:, status:, message:)
        Result.new(status:, message:, item: item)
      end

      def log(stage, item:, **extra)
        return unless defined?(Rails) && Rails.respond_to?(:logger) && Rails.logger

        payload = {
          stage: "FeedMonitor::Scraping::Enqueuer##{stage}",
          item_id: item&.id,
          source_id: source&.id,
          reason: reason
        }.merge(extra.compact)
        Rails.logger.info("[FeedMonitor::ManualScrape] #{payload.to_json}")
      rescue StandardError
        nil
      end
    end
  end
end
