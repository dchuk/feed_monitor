# frozen_string_literal: true

module FeedMonitor
  class FetchLogsController < ApplicationController
    def index
      @status = params[:status].presence_in(%w[success failed])
      @logs = scoped_logs.limit(50)
    end

    def show
      @log = FetchLog.includes(:source).find(params[:id])
    end

    private

    def scoped_logs
      scope = FetchLog.includes(:source).recent
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
