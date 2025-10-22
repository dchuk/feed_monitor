# frozen_string_literal: true

module FeedMonitor
  module Logs
    class FilterSet
      STATUS_MAP = {
        "success" => true,
        "failed" => false
      }.freeze

      LOG_TYPE_MAP = {
        "fetch" => "FeedMonitor::FetchLog",
        "scrape" => "FeedMonitor::ScrapeLog",
        "health_check" => "FeedMonitor::HealthCheckLog"
      }.freeze

      TIMEFRAME_MAP = {
        "24h" => 24.hours,
        "7d" => 7.days,
        "30d" => 30.days
      }.freeze

      MAX_PER_PAGE = 100
      DEFAULT_PER_PAGE = 25

      attr_reader :raw_params

      def initialize(params:)
        @raw_params = params || {}
      end

      def status
        @status ||= begin
          value = sanitize_string(raw_params[:status])
          STATUS_MAP.key?(value) ? value : nil
        end
      end

      def success_flag
        STATUS_MAP[status]
      end

      def log_type
        @log_type ||= begin
          value = sanitize_string(raw_params[:log_type])
          LOG_TYPE_MAP.key?(value) ? value : nil
        end
      end

      def loggable_type
        LOG_TYPE_MAP[log_type]
      end

      def timeframe
        @timeframe ||= begin
          value = sanitize_string(raw_params[:timeframe])
          TIMEFRAME_MAP.key?(value) ? value : nil
        end
      end

      def timeframe_start
        return nil unless timeframe

        current_time - TIMEFRAME_MAP.fetch(timeframe)
      end

      def started_after
        @started_after ||= parse_time_param(raw_params[:started_after])
      end

      def started_before
        @started_before ||= parse_time_param(raw_params[:started_before])
      end

      def effective_started_after
        [ timeframe_start, started_after ].compact.max
      end

      def source_id
        @source_id ||= integer_param(raw_params[:source_id])
      end

      def item_id
        @item_id ||= integer_param(raw_params[:item_id])
      end

      def search
        @search ||= begin
          value = sanitize_string(raw_params[:search])
          value.presence
        end
      end

      def page
        @page ||= begin
          integer = integer_param(raw_params[:page])
          integer.present? && integer.positive? ? integer : 1
        end
      end

      def per_page
        @per_page ||= begin
          integer = integer_param(raw_params[:per_page])
          return DEFAULT_PER_PAGE unless integer.present?

          integer = DEFAULT_PER_PAGE if integer <= 0
          [ integer, MAX_PER_PAGE ].min
        end
      end

      def to_params
        {
          status: status,
          log_type: log_type,
          timeframe: timeframe,
          started_after: started_after&.iso8601,
          started_before: started_before&.iso8601,
          source_id: source_id,
          item_id: item_id,
          search: search,
          page: page,
          per_page: per_page
        }.compact
      end

      private

      def sanitize_string(value)
        return "" if value.nil?

        FeedMonitor::Security::ParameterSanitizer.sanitize(value.to_s)
      end

      def integer_param(value)
        return nil if value.nil?

        sanitized = sanitize_string(value)
        return nil unless sanitized.match?(/\A\d+\z/)

        sanitized.to_i
      end

      def parse_time_param(value)
        return nil if value.nil?

        sanitized = sanitize_string(value)
        return nil if sanitized.blank?

        Time.iso8601(sanitized)
      rescue ArgumentError
        begin
          Time.zone.parse(sanitized)
        rescue ArgumentError, TypeError
          nil
        end
      end

      def current_time
        @current_time ||= Time.zone.now
      end
    end
  end
end
