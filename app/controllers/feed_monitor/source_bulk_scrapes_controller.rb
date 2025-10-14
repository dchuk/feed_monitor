# frozen_string_literal: true

module FeedMonitor
  class SourceBulkScrapesController < ApplicationController
    include FeedMonitor::SourceTurboResponses

    ITEMS_PREVIEW_LIMIT = FeedMonitor::Scraping::BulkSourceScraper::DEFAULT_PREVIEW_LIMIT

    before_action :set_source

    def create
      selection = bulk_scrape_params[:selection]
      normalized_selection = FeedMonitor::Scraping::BulkSourceScraper.normalize_selection(selection) || :current
      @bulk_scrape_selection = normalized_selection

      result = FeedMonitor::Scraping::BulkSourceScraper.new(
        source: @source,
        selection: normalized_selection,
        preview_limit: ITEMS_PREVIEW_LIMIT
      ).call

      respond_to_bulk_scrape(result)
    end

    private

    def set_source
      @source = Source.find(params[:source_id])
    end

    def bulk_scrape_params
      params.fetch(:bulk_scrape, {}).permit(:selection)
    end
  end
end
