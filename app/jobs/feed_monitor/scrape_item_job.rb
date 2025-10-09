# frozen_string_literal: true

module FeedMonitor
  class ScrapeItemJob < ApplicationJob
    feed_monitor_queue :scrape

    # The full scraping pipeline will be implemented in Phase 08.03.
    def perform(_item_id)
      # Intentionally left blank for now.
    end
  end
end
