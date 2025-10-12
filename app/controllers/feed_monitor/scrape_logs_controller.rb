# frozen_string_literal: true

module FeedMonitor
  class ScrapeLogsController < ApplicationController
    def index
      status_param = FeedMonitor::Security::ParameterSanitizer.sanitize(params[:status].to_s)
      @status = status_param.presence_in(%w[success failed])
      @logs = scoped_logs.limit(50)
    end

    def show
      @log = ScrapeLog.includes(:item, :source).find(params[:id])
    end

    private

    def scoped_logs
      scope = ScrapeLog.includes(:item, :source).recent

      if (item_id = integer_param(params[:item_id]))
        scope = scope.where(item_id: item_id)
      end

      if (source_id = integer_param(params[:source_id]))
        scope = scope.where(source_id: source_id)
      end

      case @status
      when "success"
        scope.successful
      when "failed"
        scope.failed
      else
        scope
      end
    end

    def integer_param(value)
      return if value.nil?

      sanitized = FeedMonitor::Security::ParameterSanitizer.sanitize(value.to_s)
      cleaned = sanitized.strip
      return if cleaned.blank?

      Integer(cleaned, exception: false)
    end
  end
end
