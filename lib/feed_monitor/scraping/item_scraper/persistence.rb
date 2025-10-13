# frozen_string_literal: true

require "active_support/core_ext/object/blank"
require "active_support/core_ext/object/deep_dup"
require "active_support/core_ext/hash/indifferent_access"

module FeedMonitor
  module Scraping
    class ItemScraper
      # Persists scrape outcomes to the database and builds a Result object.
      class Persistence
        def initialize(item:, source:, adapter_name:)
          @item = item
          @source = source
          @adapter_name = adapter_name
        end

        def persist_success(adapter_result:, started_at:)
          completed_at = Time.current
          success = adapter_result.status.to_s != "failed"
          status = normalize_status(adapter_result.status, success)
          metadata = normalize_metadata(adapter_result.metadata)
          http_status = metadata&.[](:http_status)
          error_info = success ? {} : extract_error_info(metadata)
          content_length = adapter_result.html.to_s.presence && adapter_result.html.to_s.bytesize

          log = nil
          item.class.transaction do
            apply_item_success(status:, success:, completed_at:, adapter_result:)
            log = build_log(
              started_at:,
              completed_at:,
              duration_ms: duration_ms(started_at:, completed_at:),
              success: success,
              http_status: http_status,
              content_length: content_length,
              metadata: metadata,
              error_class: error_info[:class],
              error_message: error_info[:message]
            )
          end

          FeedMonitor::Scraping::ItemScraper::Result.new(
            status: status,
            item: item,
            log: log,
            message: message_for(status, success, error_info[:message], metadata)
          )
        end

        def persist_failure(error:, started_at:, message_override: nil)
          raise ArgumentError, "Item does not belong to a source" unless source

          completed_at = Time.current
          message = message_override.presence || error.message.presence || "Scrape failed"
          http_status = extract_http_status(error)
          metadata = failure_metadata(error)

          log = nil
          item.class.transaction do
            item.update!(scrape_status: "failed", scraped_at: completed_at)
            log = build_log(
              started_at:,
              completed_at: completed_at,
              duration_ms: duration_ms(started_at:, completed_at:),
              success: false,
              http_status: http_status,
              content_length: nil,
              metadata: metadata,
              error_class: error.class.name,
              error_message: message
            )
          end

          FeedMonitor::Scraping::ItemScraper::Result.new(
            status: :failed,
            item: item,
            log: log,
            message: "Scrape failed: #{message}",
            error: error
          )
        end

        private

        attr_reader :item, :source, :adapter_name

        def apply_item_success(status:, success:, completed_at:, adapter_result:)
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

        def duration_ms(started_at:, completed_at:)
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
end
