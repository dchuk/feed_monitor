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
        clear_inflight_status(item)
        return
      end

      mark_processing(item)
      FeedMonitor::Scraping::ItemScraper.new(item:, source:).call
      log("job:completed", item: item)
    end

    private

    def mark_processing(item)
      item.with_lock do
        item.reload
        item.update_columns(scrape_status: "processing") # rubocop:disable Rails/SkipsModelValidations
      end
      log("job:mark_processing", item: item, status: item.scrape_status)
      FeedMonitor::Realtime.broadcast_item(item)
    rescue StandardError
      # If we fail to mark the item as processing (for example if it was
      # deleted mid-flight), allow the scrape to continue without the hint.
      nil
    end

    def clear_inflight_status(item)
      item.with_lock do
        item.reload
        if %w[pending processing].include?(item.scrape_status)
          item.update_columns(scrape_status: nil) # rubocop:disable Rails/SkipsModelValidations
        end
      end
      log("job:clear_inflight", item: item, status: item.scrape_status)
      FeedMonitor::Realtime.broadcast_item(item)
    rescue StandardError
      nil
    end

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
