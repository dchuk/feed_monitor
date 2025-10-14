# frozen_string_literal: true

module FeedMonitor
  module LogFiltering
    extend ActiveSupport::Concern

    private

    def status_filter
      return @status_filter if defined?(@status_filter)

      raw_status = params[:status].to_s
      sanitized = FeedMonitor::Security::ParameterSanitizer.sanitize(raw_status)
      @status_filter = sanitized.presence_in(%w[success failed])
    end

    def item_id_filter
      integer_param(:item_id)
    end

    def source_id_filter
      integer_param(:source_id)
    end

    def apply_fetch_log_filters(scope)
      scope = scope.where(success: true) if status_filter == "success"
      scope = scope.where(success: false) if status_filter == "failed"
      scope
    end

    def apply_scrape_log_filters(scope)
      scope = apply_fetch_log_filters(scope)
      scope = scope.where(item_id: item_id_filter) if item_id_filter
      scope = scope.where(source_id: source_id_filter) if source_id_filter
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
