# frozen_string_literal: true

module FeedMonitor
  class ScrapeItemJob < ApplicationJob
    feed_monitor_queue :scrape

    discard_on ActiveJob::DeserializationError

    def perform(item_id)
      item = FeedMonitor::Item.includes(:source).find_by(id: item_id)
      return unless item

      source = item.source
      unless source&.scraping_enabled?
        clear_inflight_status(item)
        return
      end

      mark_processing(item)
      FeedMonitor::Scraping::ItemScraper.new(item:, source:).call
    end

    private

    def mark_processing(item)
      item.with_lock do
        item.reload
        item.update_columns(scrape_status: "processing") # rubocop:disable Rails/SkipsModelValidations
      end
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
    rescue StandardError
      nil
    end
  end
end
