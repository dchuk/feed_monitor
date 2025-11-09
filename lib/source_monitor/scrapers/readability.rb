# frozen_string_literal: true

require "active_support/core_ext/object/blank"

require "source_monitor/scrapers/fetchers/http_fetcher"
require "source_monitor/scrapers/parsers/readability_parser"

module SourceMonitor
  module Scrapers
    class Readability < Base
      DEFAULT_ACCEPT = "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"
      FETCHER_CLASS = SourceMonitor::Scrapers::Fetchers::HttpFetcher
      PARSER_CLASS = SourceMonitor::Scrapers::Parsers::ReadabilityParser

      def self.default_settings
        {
          http: {
            headers: {
              "Accept" => DEFAULT_ACCEPT,
              "User-Agent" => SourceMonitor::HTTP::DEFAULT_USER_AGENT
            },
            timeout: SourceMonitor::HTTP::DEFAULT_TIMEOUT,
            open_timeout: SourceMonitor::HTTP::DEFAULT_OPEN_TIMEOUT,
            proxy: nil
          },
          selectors: {
            content: nil,
            title: nil
          },
          readability: {
            remove_unlikely_candidates: true,
            clean_conditionally: true,
            retry_length: 250,
            min_text_length: 25
          }
        }
      end

      def call
        url = preferred_url
        return failure_result("missing_url", "No URL available for scraping", url:) if url.blank?

        fetch_result = fetcher.fetch(url:, settings: settings[:http])
        return build_fetch_failure(fetch_result, url) if fetch_result.status == :failed

        parser_result = parser.parse(
          html: fetch_result.body.to_s,
          selectors: settings[:selectors],
          readability: settings[:readability]
        )

        return build_parser_failure(parser_result, fetch_result, url) if parser_result.status == :failed

        Result.new(
          status: parser_result.status,
          html: fetch_result.body,
          content: parser_result.content,
          metadata: build_metadata(fetch_result:, parser_result:, url:)
        )
      rescue StandardError => error
        failure_result(error.class.name, error.message, url: url)
      end

      private

      def preferred_url
        item.canonical_url.presence || item.url
      end

      def fetcher
        @fetcher ||= FETCHER_CLASS.new(http: http)
      end

      def parser
        @parser ||= PARSER_CLASS.new
      end

      def build_fetch_failure(fetch_result, url)
        failure_result(
          fetch_result.error || "fetch_error",
          fetch_result.message || "Failed to fetch URL",
          url: url,
          http_status: fetch_result.http_status
        )
      end

      def build_parser_failure(parser_result, fetch_result, url)
        metadata = {
          error: parser_result.metadata&.[](:error) || "parser_error",
          message: parser_result.metadata&.[](:message) || "Failed to parse content",
          url: url,
          http_status: fetch_result.http_status
        }.compact

        Result.new(status: :failed, html: fetch_result.body, content: nil, metadata: metadata)
      end

      def build_metadata(fetch_result:, parser_result:, url:)
        headers = fetch_result.headers || {}
        content_type = headers["content-type"] || headers["Content-Type"]

        metadata = {
          url: url,
          http_status: fetch_result.http_status,
          content_type: content_type,
          extraction_strategy: parser_result.strategy,
          title: parser_result.title,
          settings: deep_duplicate(settings)
        }.compact

        if parser_result.metadata && parser_result.metadata[:readability_text_length]
          metadata[:readability_text_length] = parser_result.metadata[:readability_text_length]
        end

        metadata
      end

      def failure_result(error, message, url:, http_status: nil)
        Result.new(
          status: :failed,
          html: nil,
          content: nil,
          metadata: {
            error: error,
            message: message,
            url: url,
            http_status: derive_status(message, http_status)
          }.compact
        )
      end

      def derive_status(message, explicit_status)
        return explicit_status if explicit_status

        return unless message

        if (match = message.match(/status\s+(\d{3})/))
          match[1].to_i
        end
      end

      def deep_duplicate(value)
        case value
        when Hash
          value.each_with_object({}) do |(key, val), memo|
            memo[key] = deep_duplicate(val)
          end
        when Array
          value.map { |element| deep_duplicate(element) }
        else
          value
        end
      end
    end
  end
end
