# frozen_string_literal: true

require "active_support/core_ext/object/blank"
require "active_support/core_ext/object/deep_dup"
require "active_support/core_ext/hash/indifferent_access"

module FeedMonitor
  module Scraping
    # Orchestrates execution of the configured scraper adapter for an item,
    # updating the item record and recording a ScrapeLog entry detailing the
    # outcome. The service is intentionally small so future adapters or
    # scheduling mechanisms can reuse it for both manual and automated flows.
    class ItemScraper
      UnknownAdapterError = Class.new(StandardError)

      Result = Struct.new(:status, :item, :log, :message, :error, keyword_init: true) do
        def success?
          status.to_s != "failed"
        end

        def failed?
          !success?
        end
      end

      attr_reader :item, :source, :adapter_name, :settings, :http

      def initialize(item:, source: nil, adapter_name: nil, settings: nil, http: FeedMonitor::HTTP)
        @item = item
        @source = source || item&.source
        @adapter_name = (adapter_name || @source&.scraper_adapter).to_s
        @settings = settings
        @http = http
      end

      def call
        started_at = Time.current
        raise ArgumentError, "Item does not belong to a source" unless source
        adapter = resolve_adapter!
        adapter_result = adapter.call(item:, source:, settings:, http:)

        success = adapter_result.status.to_s != "failed"
        result = persist_adapter_result(adapter_result, started_at, success)
        finalize_result(result)
      rescue UnknownAdapterError => error
        result = persist_failure(started_at, error, error.message)
        finalize_result(result)
      rescue StandardError => error
        result = persist_failure(started_at, error)
        finalize_result(result)
      end

      private

      def finalize_result(result)
        FeedMonitor::Events.after_item_scraped(result)
        result
      end

      def resolve_adapter!
        if adapter_name.blank?
          raise UnknownAdapterError, "No scraper adapter configured for source"
        end

        unless adapter_name.match?(/\A[a-z0-9_]+\z/i)
          raise UnknownAdapterError, "Invalid scraper adapter: #{adapter_name}"
        end

        configured = FeedMonitor.config.scrapers.adapter_for(adapter_name)
        return configured if configured

        constant = FeedMonitor::Scrapers.const_get(adapter_name.camelize)
        unless constant <= FeedMonitor::Scrapers::Base
          raise UnknownAdapterError, "Unknown scraper adapter: #{adapter_name}"
        end

        constant
      rescue NameError
        raise UnknownAdapterError, "Unknown scraper adapter: #{adapter_name}"
      end

      def persist_adapter_result(adapter_result, started_at, success)
        completed_at = Time.current
        status = normalize_status(adapter_result.status, success)
        metadata = normalize_metadata(adapter_result.metadata)
        http_status = metadata&.[](:http_status)
        error_info = success ? {} : extract_error_info(metadata)
        content_length = adapter_result.html.to_s.presence && adapter_result.html.to_s.bytesize

        log = nil

        item.class.transaction do
          apply_item_outcome(status:, success:, completed_at:, adapter_result:)
          log = build_log(
            started_at: started_at,
            completed_at: completed_at,
            duration_ms: duration_ms(started_at, completed_at),
            success: success,
            http_status: http_status,
            content_length: content_length,
            metadata: metadata,
            error_class: error_info[:class],
            error_message: error_info[:message]
          )
        end

        Result.new(
          status: status,
          item: item,
          log: log,
          message: message_for(status, success, error_info[:message], metadata)
        )
      end

      def persist_failure(started_at, error, message_override = nil)
        raise ArgumentError, "Item does not belong to a source" unless source

        completed_at = Time.current
        message = message_override.presence || error.message.presence || "Scrape failed"
        http_status = extract_http_status(error)
        metadata = failure_metadata(error)

        log = nil

        item.class.transaction do
          item.update!(scrape_status: "failed", scraped_at: completed_at)
          log = build_log(
            started_at: started_at,
            completed_at: completed_at,
            duration_ms: duration_ms(started_at, completed_at),
            success: false,
            http_status: http_status,
            content_length: nil,
            metadata: metadata,
            error_class: error.class.name,
            error_message: message
          )
        end

        Result.new(status: :failed, item: item, log: log, message: "Scrape failed: #{message}", error: error)
      end

      def apply_item_outcome(status:, success:, completed_at:, adapter_result:)
        attributes = {
          scrape_status: status.to_s,
          scraped_at: completed_at
        }

        if success
          attributes[:scraped_html] = adapter_result.html
          attributes[:scraped_content] = adapter_result.content
        end

        item.update!(attributes)
      end

      def build_log(started_at:, completed_at:, duration_ms:, success:, http_status:, content_length:, metadata:, error_class:, error_message:)
        FeedMonitor::ScrapeLog.create!(
          source: source,
          item: item,
          success: success,
          scraper_adapter: adapter_name,
          started_at: started_at,
          completed_at: completed_at,
          duration_ms: duration_ms,
          http_status: http_status,
          content_length: content_length,
          error_class: error_class,
          error_message: error_message,
          metadata: metadata
        )
      end

      def normalize_status(raw_status, success)
        return :success if raw_status.blank? && success
        return :failed if raw_status.blank?

        raw_status.to_sym
      end

      def normalize_metadata(metadata)
        return {} if metadata.blank?

        hash = metadata.respond_to?(:to_h) ? metadata.to_h : metadata
        hash.deep_dup.with_indifferent_access
      rescue StandardError
        {}
      end

      def extract_error_info(metadata)
        {
          class: metadata&.[](:error)&.to_s,
          message: metadata&.[](:message)&.to_s
        }.compact
      end

      def failure_metadata(error)
        {
          error: error.class.name,
          message: error.message,
          backtrace: Array(error.backtrace).first(5)
        }.compact
      end

      def extract_http_status(error)
        return error.http_status if error.respond_to?(:http_status) && error.http_status.present?

        if error.respond_to?(:response)
          response = error.response
          if response.is_a?(Hash)
            return response[:status] || response["status"]
          end
        end

        if error.message && (match = error.message.match(/\b(\d{3})\b/))
          return match[1].to_i
        end

        nil
      end

      def duration_ms(started_at, completed_at)
        return nil unless started_at && completed_at

        ((completed_at - started_at) * 1000).round
      end

      def message_for(status, success, error_message, metadata)
        return "Scrape failed: #{error_message}" if !success && error_message.present?

        case status.to_s
        when "success"
          strategy = metadata&.[](:extraction_strategy)
          strategy.present? ? "Scrape completed via #{strategy.to_s.titleize}" : "Scrape completed successfully"
        when "partial"
          "Scrape completed with partial content"
        else
          success ? "Scrape completed" : "Scrape failed"
        end
      end
    end
  end
end
