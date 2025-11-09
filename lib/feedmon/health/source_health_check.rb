# frozen_string_literal: true

module Feedmon
  module Health
    class SourceHealthCheck
      Result = Struct.new(:log, :success?, :error, keyword_init: true)

      def initialize(source:, client: nil, now: Time.current)
        @source = source
        @client = client
        @now = now
      end

      def call
        return Result.new(log: nil, success?: false, error: nil) unless source

        started_at = now
        response = nil
        error = nil

        begin
          response = connection.get(source.feed_url)
        rescue StandardError => exception
          error = exception
        end

        completed_at = Time.current
        log = create_log(response:, error:, started_at:, completed_at:)

        Result.new(log:, success?: log&.success?, error: error)
      end

      private

      attr_reader :source, :client, :now

      def connection
        @connection ||= (client || Feedmon::HTTP.client(headers: request_headers, retry_requests: false))
      end

      def request_headers
        headers = (source.custom_headers || {}).each_with_object({}) do |(key, value), memo|
          memo[key.to_s] = value
        end

        headers["If-None-Match"] = source.etag if source.etag.present?
        headers["If-Modified-Since"] = source.last_modified.httpdate if source.last_modified.present?
        headers
      end

      def create_log(response:, error:, started_at:, completed_at:)
        attrs = {
          source: source,
          started_at: started_at,
          completed_at: completed_at,
          duration_ms: duration_ms(started_at, completed_at),
          http_status: response_status(response, error),
          http_response_headers: response_headers(response)
        }

        if error
          attrs[:success] = false
          attrs[:error_class] = error.class.name
          attrs[:error_message] = error.message
        else
          attrs[:success] = successful_status?(response&.status)
        end

        Feedmon::HealthCheckLog.create!(attrs)
      end

      def duration_ms(started_at, completed_at)
        ((completed_at - started_at) * 1000.0).round
      end

      def response_status(response, error)
        return response.status if response&.respond_to?(:status)

        if error.respond_to?(:response)
          response_data = error.response
          return response_data[:status] if response_data.is_a?(Hash)
        end

        nil
      end

      def response_headers(response)
        return {} unless response&.respond_to?(:headers)

        response.headers.each_with_object({}) do |(key, value), memo|
          memo[key.to_s] = value
        end
      end

      def successful_status?(status)
        status.present? && status.to_i.between?(200, 399)
      end
    end
  end
end
