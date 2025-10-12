# frozen_string_literal: true

module FeedMonitor
  module LogFiltering
    extend ActiveSupport::Concern

    private

    def log_filter_status
      return @log_filter_status if defined?(@log_filter_status)

      raw_status = params[:status].to_s
      sanitized = FeedMonitor::Security::ParameterSanitizer.sanitize(raw_status)
      @log_filter_status = sanitized.presence_in(%w[success failed])
    end

    def log_filter_item_id
      integer_param(:item_id)
    end

    def log_filter_source_id
      integer_param(:source_id)
    end

    def filter_fetch_logs(scope)
      scope = scope.where(success: true) if log_filter_status == "success"
      scope = scope.where(success: false) if log_filter_status == "failed"
      scope
    end

    def filter_scrape_logs(scope)
      scope = filter_fetch_logs(scope)
      scope = scope.where(item_id: log_filter_item_id) if log_filter_item_id
      scope = scope.where(source_id: log_filter_source_id) if log_filter_source_id
      scope
    end

    def integer_param(key)
      return nil unless params.key?(key)

      raw_value = params[key]
      raw_string = raw_value.to_s
      stripped = raw_string.strip

      return nil unless stripped.match?(/\A\d+\z/)

      sanitized = FeedMonitor::Security::ParameterSanitizer.sanitize(raw_string).strip
      return nil if sanitized.blank?

      sanitized.to_i
    end
  end
end
