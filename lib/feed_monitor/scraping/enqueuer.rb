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
        rate_limited = false
        rate_limit_info = nil

        item.with_lock do
          item.reload

          if FeedMonitor::Scraping::State.in_flight?(item.scrape_status)
            log("enqueue:in_flight", item:, status: item.scrape_status)
            already_queued = true
            next
          end

          exhausted, info = rate_limit_exhausted?
          if exhausted
            rate_limited = true
            rate_limit_info = info
            next
          end

          FeedMonitor::Scraping::State.mark_pending!(item, broadcast: false, lock: false)
        end

        if already_queued
          log("enqueue:already_enqueued", item:, status: item.scrape_status)
          return Result.new(status: :already_enqueued, message: "Scrape already in progress for this item.", item: item)
        end

        if rate_limited
          message = rate_limit_message(rate_limit_info)
          log("enqueue:rate_limited", item:, limit: rate_limit_info&.fetch(:limit, nil), in_flight: rate_limit_info&.fetch(:in_flight, nil))
          return Result.new(status: :rate_limited, message:, item: item)
        end

        job_class.perform_later(item.id)
        log("enqueue:job_enqueued", item:, job_class: job_class.name)
        Result.new(status: :enqueued, message: "Scrape has been enqueued for processing.", item: item)
      end

      private

      def auto_reason?
        reason == :auto
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

      def rate_limit_exhausted?
        limit = FeedMonitor.config.scraping.max_in_flight_per_source
        return [false, nil] unless limit

        in_flight = source.items.where(scrape_status: FeedMonitor::Scraping::State::IN_FLIGHT_STATUSES).count
        [in_flight >= limit, { limit:, in_flight: in_flight }]
      end

      def rate_limit_message(info)
        return "Scraping queue is full for this source." unless info

        limit = info[:limit]
        in_flight = info[:in_flight]
        "Unable to enqueue scrape: scraping queue is full for this source (#{in_flight}/#{limit} jobs in flight)."
      end
    end
  end
end
