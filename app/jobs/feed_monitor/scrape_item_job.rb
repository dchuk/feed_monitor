# frozen_string_literal: true

module FeedMonitor
  class ScrapeItemJob < ApplicationJob
    feed_monitor_queue :scrape

    discard_on ActiveJob::DeserializationError

    def perform(item_id)
      log("job:start", item_id: item_id)
      item = FeedMonitor::Item.includes(:source).find_by(id: item_id)
      return unless item

      source = item.source
      unless source&.scraping_enabled?
        log("job:skipped_scraping_disabled", item: item)
        FeedMonitor::Scraping::State.clear_inflight!(item)
        return
      end

      FeedMonitor::Scraping::State.mark_processing!(item)
      FeedMonitor::Scraping::ItemScraper.new(item:, source:).call
      log("job:completed", item: item, status: item.scrape_status)
    rescue StandardError => error
      log("job:error", item: item, error: error.message)
      FeedMonitor::Scraping::State.mark_failed!(item)
      raise
    ensure
      FeedMonitor::Scraping::State.clear_inflight!(item) if item
    end

    private

    def log(stage, item: nil, item_id: nil, **extra)
      return unless defined?(Rails) && Rails.respond_to?(:logger) && Rails.logger

      payload = {
        stage: "FeedMonitor::ScrapeItemJob##{stage}",
        item_id: item&.id || item_id,
        source_id: item&.source_id
      }.merge(extra.compact)
      Rails.logger.info("[FeedMonitor::ManualScrape] #{payload.to_json}")
    rescue StandardError
      nil
    end
  end
end
