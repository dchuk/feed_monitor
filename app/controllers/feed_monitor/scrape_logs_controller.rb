# frozen_string_literal: true

module FeedMonitor
  class ScrapeLogsController < ApplicationController
    include FeedMonitor::LogFiltering

    def index
      @status = log_filter_status
      @item_id = log_filter_item_id
      @source_id = log_filter_source_id
      @logs = filter_scrape_logs(base_scope).limit(50)
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
