# frozen_string_literal: true

module FeedMonitor
  module Scraping
    # Orchestrates execution of the configured scraper adapter for an item,
    # updating the item record and recording a ScrapeLog entry detailing the
    # outcome. The service is intentionally small so future adapters or
    # scheduling mechanisms can reuse it for both manual and automated flows.
    class ItemScraper
      UnknownAdapterError = Class.new(StandardError)

      Result = Struct.new(:status, :item, :log, :message, :error, keyword_init: true) do
        def success?
          status.to_s != "failed"
        end

        def failed?
          !success?
        end
      end

      attr_reader :item, :source, :adapter_name, :settings, :http, :adapter_resolver, :persistence

      def initialize(item:, source: nil, adapter_name: nil, settings: nil, http: FeedMonitor::HTTP)
        @item = item
        @source = source || item&.source
        @adapter_name = (adapter_name || @source&.scraper_adapter).to_s
        @settings = settings
        @http = http
        @adapter_resolver = FeedMonitor::Scraping::ItemScraper::AdapterResolver.new(name: @adapter_name, source: @source)
        @persistence = FeedMonitor::Scraping::ItemScraper::Persistence.new(item: @item, source: @source, adapter_name: @adapter_name)
      end

      def call
        started_at = Time.current
        log("scraper:start", started_at:, item:, source:)
        raise ArgumentError, "Item does not belong to a source" unless source
        adapter = adapter_resolver.resolve!
        adapter_result = adapter.call(item:, source:, settings:, http:)

        result = persistence.persist_success(adapter_result:, started_at:)
        finalize_result(result)
      rescue UnknownAdapterError => error
        log("scraper:unknown_adapter", error: error.message)
        result = persistence.persist_failure(error:, started_at:, message_override: error.message)
        finalize_result(result)
      rescue StandardError => error
        log("scraper:exception", error: error.message)
        result = persistence.persist_failure(error:, started_at:)
        finalize_result(result)
      end

      private

      def finalize_result(result)
        log(
          "scraper:finalize",
          status: result&.status,
          scrape_status: result&.item&.scrape_status,
          log_id: result&.log&.id
        )
        FeedMonitor::Events.after_item_scraped(result)
        result
      end

      def log(stage, **extra)
        return unless defined?(Rails) && Rails.respond_to?(:logger) && Rails.logger

        payload = {
          stage: "FeedMonitor::Scraping::ItemScraper##{stage}",
          item_id: item&.id,
          source_id: source&.id,
          adapter: adapter_name
        }.merge(extra.compact)
        Rails.logger.info("[FeedMonitor::ManualScrape] #{payload.to_json}")
      rescue StandardError
        nil
      end
    end
  end
end
