# frozen_string_literal: true

require "faraday"
require "faraday/retry"
require "faraday/follow_redirects"
require "faraday/gzip"

module FeedMonitor
  module HTTP
    DEFAULT_TIMEOUT = 15
    DEFAULT_OPEN_TIMEOUT = 5
    DEFAULT_MAX_REDIRECTS = 5
    DEFAULT_USER_AGENT = "FeedMonitor/#{FeedMonitor::VERSION}"
    RETRY_STATUSES = [429, 500, 502, 503, 504].freeze

    class << self
      def client(proxy: nil, headers: {}, timeout: DEFAULT_TIMEOUT, open_timeout: DEFAULT_OPEN_TIMEOUT)
        Faraday.new(nil, proxy: proxy) do |connection|
          configure_request(connection, headers, timeout: timeout, open_timeout: open_timeout)
        end
      end

      private

      def configure_request(connection, headers, timeout:, open_timeout:) # rubocop:disable Metrics/MethodLength
        connection.request :retry,
                           max: 4,
                           interval: 0.5,
                           interval_randomness: 0.5,
                           backoff_factor: 2,
                           retry_statuses: RETRY_STATUSES
        connection.request :gzip

        connection.response :follow_redirects, limit: DEFAULT_MAX_REDIRECTS
        connection.response :raise_error

        connection.options.timeout = timeout
        connection.options.open_timeout = open_timeout

        default_headers.merge(headers).each do |key, value|
          connection.headers[key] = value
        end

        connection.adapter Faraday.default_adapter
      end

      def default_headers
        {
          "User-Agent" => DEFAULT_USER_AGENT,
          "Accept" => "application/rss+xml, application/atom+xml, application/json;q=0.9, text/xml;q=0.8",
          "Accept-Encoding" => "gzip,deflate"
        }
      end
    end
  end
end
