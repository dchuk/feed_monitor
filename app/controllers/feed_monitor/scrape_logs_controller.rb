# frozen_string_literal: true

module FeedMonitor
  class ScrapeLogsController < ApplicationController
    def index
      @status = params[:status].presence_in(%w[success failed])
      @logs = scoped_logs.limit(50)
    end

    def show
      @log = ScrapeLog.includes(:item, :source).find(params[:id])
    end

    private

    def scoped_logs
      scope = ScrapeLog.includes(:item, :source).recent
      case @status
      when "success"
        scope.successful
      when "failed"
        scope.failed
      else
        scope
      end
    end
  end
end
