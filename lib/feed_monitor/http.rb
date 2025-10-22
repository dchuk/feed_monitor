# frozen_string_literal: true

require "faraday"
require "faraday/retry"
require "faraday/follow_redirects"
require "faraday/gzip"
require "active_support/core_ext/object/blank"

module FeedMonitor
  module HTTP
    DEFAULT_TIMEOUT = 15
    DEFAULT_OPEN_TIMEOUT = 5
    DEFAULT_MAX_REDIRECTS = 5
    DEFAULT_USER_AGENT = "FeedMonitor/#{FeedMonitor::VERSION}"
    RETRY_STATUSES = [ 429, 500, 502, 503, 504 ].freeze

    class << self
      def client(proxy: nil, headers: {}, timeout: nil, open_timeout: nil, retry_requests: true)
        settings = FeedMonitor.config.http

        effective_proxy = resolve_proxy(proxy, settings)
        effective_timeout = timeout || settings.timeout || DEFAULT_TIMEOUT
        effective_open_timeout = open_timeout || settings.open_timeout || DEFAULT_OPEN_TIMEOUT

        Faraday.new(nil, proxy: effective_proxy) do |connection|
          configure_request(
            connection,
            headers,
            timeout: effective_timeout,
            open_timeout: effective_open_timeout,
            settings: settings,
            enable_retry: retry_requests
          )
        end
      end

      private

      def configure_request(connection, headers, timeout:, open_timeout:, settings:, enable_retry:) # rubocop:disable Metrics/MethodLength
        if enable_retry
          connection.request :retry,
                             max: settings.retry_max || 4,
                             interval: settings.retry_interval || 0.5,
                             interval_randomness: settings.retry_interval_randomness || 0.5,
                             backoff_factor: settings.retry_backoff_factor || 2,
                             retry_statuses: settings.retry_statuses || RETRY_STATUSES
        end
        connection.request :gzip

        connection.response :follow_redirects, limit: settings.max_redirects || DEFAULT_MAX_REDIRECTS
        connection.response :raise_error

        connection.options.timeout = timeout
        connection.options.open_timeout = open_timeout

        default_headers(settings).merge(headers).each do |key, value|
          connection.headers[key] = value
        end

        connection.adapter Faraday.default_adapter
      end

      def default_headers(settings)
        base_headers = {
          "User-Agent" => resolve_callable(settings.user_agent).presence || DEFAULT_USER_AGENT,
          "Accept" => "application/rss+xml, application/atom+xml, application/json;q=0.9, text/xml;q=0.8",
          "Accept-Encoding" => "gzip,deflate"
        }

        base_headers.merge(settings.headers || {})
      end

      def resolve_proxy(proxy, settings)
        return nil if proxy == false
        return proxy unless proxy.nil?

        resolve_callable(settings.proxy)
      end

      def resolve_callable(value)
        value.respond_to?(:call) ? value.call : value
      end
    end
  end
end
