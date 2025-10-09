# frozen_string_literal: true

require "readability"
require "nokolexbor"
require "active_support/core_ext/hash/keys"

module FeedMonitor
  module Scrapers
    class Readability < Base
      DEFAULT_ACCEPT = "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"

      def self.default_settings
        {
          http: {
            headers: {
              "Accept" => DEFAULT_ACCEPT,
              "User-Agent" => FeedMonitor::HTTP::DEFAULT_USER_AGENT
            },
            timeout: FeedMonitor::HTTP::DEFAULT_TIMEOUT,
            open_timeout: FeedMonitor::HTTP::DEFAULT_OPEN_TIMEOUT,
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

        response = fetch_response(url)
        return response if response.is_a?(Result)

        html = response.body.to_s
        document = ::Nokolexbor::HTML(html)
        extraction = extract_content(document, html)

        Result.new(
          status: extraction[:status],
          html: html,
          content: extraction[:content],
          metadata: build_metadata(response:, url:, document:, extraction:)
        )
      rescue StandardError => error
        failure_result(error.class.name, error.message, url: url)
      end

      private

      def preferred_url
        item.canonical_url.presence || item.url
      end

      def fetch_response(url)
        response = connection.get(url)
        return response if success_status?(response.status)

        failure_result("http_error", "Non-success HTTP status", url:, http_status: response.status)
      rescue Faraday::ClientError => error
        status = extract_status_from(error)
        failure_result(error.class.name, error.message, url: url, http_status: status)
      rescue Faraday::Error => error
        failure_result(error.class.name, error.message, url: url)
      end

      def connection
        @connection ||= begin
          http_settings = settings[:http] || {}
          client_options = {
            headers: http_settings[:headers].to_h,
            timeout: http_settings[:timeout] || FeedMonitor::HTTP::DEFAULT_TIMEOUT,
            open_timeout: http_settings[:open_timeout] || FeedMonitor::HTTP::DEFAULT_OPEN_TIMEOUT
          }

          proxy = http_settings[:proxy]
          client_options[:proxy] = proxy if proxy.present?

          http.client(**client_options)
        end
      end

      def extract_content(document, html)
        selectors = settings.dig(:selectors, :content)
        if selectors.present?
          content_html = extract_with_selectors(document, selectors)
          return { status: :success, content: content_html, strategy: :selectors } if content_html.present?
        end

        readability_doc = build_readability_document(html)
        content_html = readability_doc.content&.strip
        status = content_html.present? ? :success : :partial

        { status:, content: content_html.presence, strategy: :readability, readability: readability_doc }
      end

      def extract_with_selectors(document, selectors)
        fragments = Array(selectors).filter_map do |selector|
          next if selector.blank?

          nodes = document.css(selector.to_s)
          next if nodes.empty?

          nodes.map(&:to_html).join("\n")
        end

        return if fragments.empty?

        fragments.join("\n")
      end

      def build_readability_document(html)
        options = (settings[:readability] || {}).to_h.deep_symbolize_keys
        ::Readability::Document.new(html, options)
      end

      def build_metadata(response:, url:, document:, extraction:)
        metadata = {
          url: url,
          http_status: response.status,
          extraction_strategy: extraction[:strategy],
          content_type: response.headers["content-type"],
          settings: settings.deep_dup
        }

        metadata[:title] = extract_title(document, extraction)
        metadata[:readability_text_length] = extraction.dig(:readability, :content_length) if extraction[:readability].respond_to?(:content_length)

        metadata
      end

      def extract_title(document, extraction)
        title_selector = settings.dig(:selectors, :title)
        if title_selector.present?
          Array(title_selector).each do |selector|
            node = document.at_css(selector.to_s)
            return node.text.strip if node&.text.present?
          end
        end

        readability = extraction[:readability]
        if readability.respond_to?(:title)
          return readability.title&.strip if readability.title.present?
        end

        document.at_css("title")&.text&.strip
      end

      def success_status?(status)
        status >= 200 && status < 300
      end

      def failure_result(error, message, url:, http_status: nil)
        metadata = {
          error: error,
          message: message,
          url: url,
          http_status: http_status
        }

        if metadata[:http_status].nil? && message
          if (match = message.match(/status\s+(\d{3})/))
            metadata[:http_status] = match[1].to_i
          end
        end

        Result.new(
          status: :failed,
          html: nil,
          content: nil,
          metadata: metadata.compact
        )
      end

      def extract_status_from(error)
        if error.respond_to?(:response_status)
          status = error.response_status
          return status if status
        end

        if error.respond_to?(:response)
          response = error.response
          if response.respond_to?(:[]) && response[:status]
            return response[:status]
          elsif response.is_a?(Hash)
            return response["status"] || response[:status]
          end
        end

        if error.respond_to?(:message)
          match = error.message.match(/status\s+(\d{3})/)
          return match[1].to_i if match
        end

        nil
      end
    end
  end
end
