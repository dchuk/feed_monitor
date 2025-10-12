# frozen_string_literal: true

module FeedMonitor
  class FetchLogsController < ApplicationController
    include FeedMonitor::LogFiltering

    def index
      @status = log_filter_status
      @logs = filter_fetch_logs(base_scope).limit(50)
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
