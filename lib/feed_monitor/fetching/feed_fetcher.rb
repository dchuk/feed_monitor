# frozen_string_literal: true

require "time"
require "feed_monitor/http"

module FeedMonitor
  module Fetching
    class FeedFetcher
      Result = Struct.new(:status, :feed, :response, :body, keyword_init: true)

      attr_reader :source, :client

      def initialize(source:, client: nil)
        @source = source
        @client = client
      end

      def call
        started_at = Time.current

        FeedMonitor::Instrumentation.fetch(source_id: source.id, feed_url: source.feed_url) do
          response = perform_request
          duration_ms = elapsed_ms(started_at)

          case response.status
          when 200
            handle_success(response, duration_ms, started_at)
          when 304
            handle_not_modified(response, duration_ms, started_at)
          else
            Result.new(status: :unexpected_status, response:, body: response.body)
          end
        end
      end

      private

      def perform_request
        connection.get(source.feed_url)
      end

      def connection
        @connection ||= (client || FeedMonitor::HTTP.client(headers: request_headers))
      end

      def request_headers
        headers = (source.custom_headers || {}).transform_keys { |key| key.to_s }
        headers["If-None-Match"] = source.etag if source.etag.present?
        headers["If-Modified-Since"] = source.last_modified.httpdate if source.last_modified.present?
        headers
      end

      def handle_success(response, duration_ms, started_at)
        body = response.body
        feed = Feedjira.parse(body)

        update_source_for_success(response, duration_ms, feed)
        create_fetch_log(response, duration_ms, started_at, feed:, success: true, body:)

        Result.new(status: :fetched, feed:, response:, body:)
      end

      def handle_not_modified(response, duration_ms, started_at)
        update_source_for_not_modified(response, duration_ms)
        create_fetch_log(response, duration_ms, started_at, success: true)

        Result.new(status: :not_modified, response:, body: nil)
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
          if (parsed_time = parse_http_time(last_modified_header))
            attributes[:last_modified] = parsed_time
          end
        end

        source.update!(attributes)
      end

      def update_source_for_not_modified(response, duration_ms)
        attributes = {
          last_fetched_at: Time.current,
          last_fetch_duration_ms: duration_ms,
          last_http_status: response.status
        }

        if (etag = response.headers["etag"] || response.headers["ETag"])
          attributes[:etag] = etag
        end

        if (last_modified_header = response.headers["last-modified"] || response.headers["Last-Modified"])
          if (parsed_time = parse_http_time(last_modified_header))
            attributes[:last_modified] = parsed_time
          end
        end

        source.update!(attributes)
      end

      def create_fetch_log(response, duration_ms, started_at, feed: nil, success:, body: nil)
        source.fetch_logs.create!(
          success:,
          started_at: started_at,
          completed_at: started_at + (duration_ms / 1000.0),
          duration_ms: duration_ms,
          http_status: response.status,
          http_response_headers: normalized_headers(response.headers),
          feed_size_bytes: body&.bytesize,
          items_in_feed: feed&.respond_to?(:entries) ? feed.entries.size : nil,
          metadata: feed_metadata(feed)
        )
      end

      def derive_feed_format(feed)
        return unless feed

        feed.class.name.split("::").last.underscore
      end

      def feed_metadata(feed)
        return {} unless feed

        { parser: feed.class.name }
      end

      def normalized_headers(headers)
        headers.to_h.transform_keys { |key| key.to_s.downcase }
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
    end
  end
end
