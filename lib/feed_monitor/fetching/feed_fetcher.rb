# frozen_string_literal: true

require "time"
require "feed_monitor/http"
require "feed_monitor/fetching/fetch_error"

module FeedMonitor
  module Fetching
    class FeedFetcher
      Result = Struct.new(:status, :feed, :response, :body, :error, keyword_init: true)
      ResponseWrapper = Struct.new(:status, :headers, :body, keyword_init: true)

      attr_reader :source, :client

      def initialize(source:, client: nil)
        @source = source
        @client = client
      end

      def call
        attempt_started_at = Time.current
        instrumentation_payload = base_instrumentation_payload
        started_monotonic = FeedMonitor::Instrumentation.monotonic_time
        result = nil

        FeedMonitor::Instrumentation.fetch_start(instrumentation_payload)

        result = perform_fetch(attempt_started_at, instrumentation_payload)
      rescue FetchError => error
        result = handle_failure(error, started_at: attempt_started_at, instrumentation_payload:)
      rescue StandardError => error
        fetch_error = UnexpectedResponseError.new(error.message, original_error: error)
        result = handle_failure(fetch_error, started_at: attempt_started_at, instrumentation_payload:)
      ensure
        instrumentation_payload[:duration_ms] ||= duration_since(started_monotonic)
        FeedMonitor::Instrumentation.fetch_finish(instrumentation_payload)
        return result
      end

      private

      def base_instrumentation_payload
        {
          source_id: source.id,
          feed_url: source.feed_url
        }
      end

      def duration_since(started_monotonic)
        ((FeedMonitor::Instrumentation.monotonic_time - started_monotonic) * 1000.0).round(2)
      end

      def perform_fetch(started_at, instrumentation_payload)
        response = perform_request
        handle_response(response, started_at, instrumentation_payload)
      rescue TimeoutError, ConnectionError, HTTPError, ParsingError => error
        raise error
      rescue Faraday::TimeoutError => error
        raise TimeoutError.new(error.message, original_error: error)
      rescue Faraday::ConnectionFailed, Faraday::SSLError => error
        raise ConnectionError.new(error.message, original_error: error)
      rescue Faraday::ClientError => error
        raise build_http_error_from_faraday(error)
      rescue Faraday::Error => error
        raise FetchError.new(error.message, original_error: error)
      end

      def perform_request
        connection.get(source.feed_url)
      end

      def connection
        @connection ||= (client || FeedMonitor::HTTP.client(headers: request_headers))
      end

      def request_headers
        headers = (source.custom_headers || {}).transform_keys { |key| key.to_s }
        headers["If-None-Match"] = source.etag if source.etag.present?
        if source.last_modified.present?
          headers["If-Modified-Since"] = source.last_modified.httpdate
        end
        headers
      end

      def handle_response(response, started_at, instrumentation_payload)
        case response.status
        when 200
          handle_success(response, started_at, instrumentation_payload)
        when 304
          handle_not_modified(response, started_at, instrumentation_payload)
        else
          raise HTTPError.new(status: response.status, response: response)
        end
      end

      def handle_success(response, started_at, instrumentation_payload)
        duration_ms = elapsed_ms(started_at)
        body = response.body
        feed = parse_feed(body, response)

        update_source_for_success(response, duration_ms, feed)
        create_fetch_log(
          response: response,
          duration_ms: duration_ms,
          started_at: started_at,
          feed: feed,
          success: true,
          body: body
        )

        instrumentation_payload[:success] = true
        instrumentation_payload[:status] = :fetched
        instrumentation_payload[:http_status] = response.status
        instrumentation_payload[:parser] = feed.class.name if feed

        Result.new(status: :fetched, feed:, response:, body:)
      end

      def handle_not_modified(response, started_at, instrumentation_payload)
        duration_ms = elapsed_ms(started_at)

        update_source_for_not_modified(response, duration_ms)
        create_fetch_log(
          response: response,
          duration_ms: duration_ms,
          started_at: started_at,
          success: true
        )

        instrumentation_payload[:success] = true
        instrumentation_payload[:status] = :not_modified
        instrumentation_payload[:http_status] = response.status

        Result.new(status: :not_modified, response:, body: nil)
      end

      def parse_feed(body, response)
        Feedjira.parse(body)
      rescue StandardError => error
        raise ParsingError.new(error.message, response: response, original_error: error)
      end

      def update_source_for_success(response, duration_ms, feed)
        attributes = {
          last_fetched_at: Time.current,
          last_fetch_duration_ms: duration_ms,
          last_http_status: response.status,
          last_error: nil,
          last_error_at: nil,
          failure_count: 0,
          feed_format: derive_feed_format(feed)
        }

        if (etag = response.headers["etag"] || response.headers["ETag"])
          attributes[:etag] = etag
        end

        if (last_modified_header = response.headers["last-modified"] || response.headers["Last-Modified"])
          parsed_time = parse_http_time(last_modified_header)
          attributes[:last_modified] = parsed_time if parsed_time
        end

        source.update!(attributes)
      end

      def update_source_for_not_modified(response, duration_ms)
        attributes = {
          last_fetched_at: Time.current,
          last_fetch_duration_ms: duration_ms,
          last_http_status: response.status,
          last_error: nil,
          last_error_at: nil,
          failure_count: 0
        }

        if (etag = response.headers["etag"] || response.headers["ETag"])
          attributes[:etag] = etag
        end

        if (last_modified_header = response.headers["last-modified"] || response.headers["Last-Modified"])
          parsed_time = parse_http_time(last_modified_header)
          attributes[:last_modified] = parsed_time if parsed_time
        end

        source.update!(attributes)
      end

      def update_source_for_failure(error, duration_ms)
        now = Time.current
        attrs = {
          last_fetched_at: now,
          last_fetch_duration_ms: duration_ms,
          last_http_status: error.http_status,
          last_error: error.message,
          last_error_at: now,
          failure_count: source.failure_count.to_i + 1
        }

        source.update!(attrs)
      end

      def create_fetch_log(response:, duration_ms:, started_at:, success:, feed: nil, error: nil, body: nil)
        source.fetch_logs.create!(
          success:,
          started_at: started_at,
          completed_at: started_at + (duration_ms / 1000.0),
          duration_ms: duration_ms,
          http_status: response&.status,
          http_response_headers: normalized_headers(response&.headers),
          feed_size_bytes: body&.bytesize,
          items_in_feed: feed&.respond_to?(:entries) ? feed.entries.size : nil,
          error_class: error&.class&.name,
          error_message: error&.message,
          error_backtrace: error_backtrace(error),
          metadata: feed_metadata(feed, error: error)
        )
      end

      def derive_feed_format(feed)
        return unless feed

        feed.class.name.split("::").last.underscore
      end

      def feed_metadata(feed, error: nil)
        metadata = {}
        metadata[:parser] = feed.class.name if feed
        metadata[:error_code] = error.code if error&.respond_to?(:code)
        metadata
      end

      def normalized_headers(headers)
        return {} unless headers

        headers.to_h.transform_keys { |key| key.to_s.downcase }
      end

      def error_backtrace(error)
        return if error.nil? || error.original_error.nil?

        Array(error.original_error.backtrace).first(20).join("\n")
      end

      def parse_http_time(value)
        return if value.blank?

        Time.httpdate(value)
      rescue ArgumentError
        nil
      end

      def elapsed_ms(started_at)
        ((Time.current - started_at) * 1000.0).round
      end

      def handle_failure(error, started_at:, instrumentation_payload:)
        response = error.response
        body = response&.body
        duration_ms = elapsed_ms(started_at)

        update_source_for_failure(error, duration_ms)
        create_fetch_log(
          response: response,
          duration_ms: duration_ms,
          started_at: started_at,
          success: false,
          error: error,
          body: body
        )

        instrumentation_payload[:success] = false
        instrumentation_payload[:status] = :failed
        instrumentation_payload[:error_class] = error.class.name
        instrumentation_payload[:error_message] = error.message
        instrumentation_payload[:http_status] = error.http_status if error.http_status
        instrumentation_payload[:error_code] = error.code if error.respond_to?(:code)

        Result.new(status: :failed, response: response, body: body, error: error)
      end

      def build_http_error_from_faraday(error)
        response_hash = error.response || {}
        headers = response_hash[:headers] || response_hash[:response_headers] || {}
        ResponseWrapper.new(
          status: response_hash[:status],
          headers: headers,
          body: response_hash[:body]
        ).then do |response|
          status = response.status || 0
          message = error.message
          HTTPError.new(status: status, message: message, response: response, original_error: error)
        end
      end
    end
  end
end
