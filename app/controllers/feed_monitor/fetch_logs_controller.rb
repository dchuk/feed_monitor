# frozen_string_literal: true

module FeedMonitor
  class FetchLogsController < ApplicationController
    include FeedMonitor::LogFiltering

    def index
      @status = status_filter
      @logs = apply_fetch_log_filters(base_scope).limit(50)
    end

    def show
      @log = FetchLog.includes(:source).find(params[:id])
    end

    private

    def base_scope
      FetchLog.includes(:source).recent
    end
  end
end
