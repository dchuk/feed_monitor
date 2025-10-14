# frozen_string_literal: true

module FeedMonitor
  class ScrapeLogsController < ApplicationController
    include FeedMonitor::LogFiltering

    def index
      @status = status_filter
      @item_id = item_id_filter
      @source_id = source_id_filter
      @logs = apply_scrape_log_filters(base_scope).limit(50)
    end

    def show
      @log = ScrapeLog.includes(:item, :source).find(params[:id])
    end

    private

    def base_scope
      ScrapeLog.includes(:item, :source).recent
    end
  end
end
