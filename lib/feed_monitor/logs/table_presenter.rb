# frozen_string_literal: true

module FeedMonitor
  module Logs
    class TablePresenter
      class Row
        def initialize(entry, url_helpers)
          @entry = entry
          @url_helpers = url_helpers
        end

        def dom_id
          "#{type_slug}-#{entry.loggable_id}"
        end

        def type_label
          fetch? ? "Fetch" : "Scrape"
        end

        def type_variant
          fetch? ? :fetch : :scrape
        end

        def status_label
          entry.success? ? "Success" : "Failure"
        end

        def status_variant
          entry.success? ? :success : :failure
        end

        def started_at
          entry.started_at
        end

        def primary_label
          if scrape?
            entry.item&.title.presence || "(untitled)"
          else
            entry.source&.name
          end
        end

        def primary_path
          if scrape? && entry.item
            url_helpers.item_path(entry.item)
          else
            url_helpers.source_path(entry.source) if entry.source
          end
        end

        def source_label
          entry.source&.name
        end

        def source_path
          url_helpers.source_path(entry.source) if entry.source
        end

        def http_summary
          if fetch?
            entry.http_status.present? ? entry.http_status.to_s : "—"
          else
            parts = []
            parts << entry.http_status.to_s if entry.http_status
            parts << entry.scraper_adapter if entry.scraper_adapter.present?
            parts.compact.join(" · ").presence || "—"
          end
        end

        def metrics_summary
          if fetch?
            "+#{entry.items_created.to_i} / ~#{entry.items_updated.to_i} / ✕#{entry.items_failed.to_i}"
          else
            entry.duration_ms.present? ? "#{entry.duration_ms} ms" : "—"
          end
        end

        def detail_path
          case entry.loggable
          when FeedMonitor::FetchLog
            url_helpers.fetch_log_path(entry.loggable)
          when FeedMonitor::ScrapeLog
            url_helpers.scrape_log_path(entry.loggable)
          end
        end

        def adapter
          entry.scraper_adapter
        end

        def success?
          entry.success?
        end

        def failure?
          !success?
        end

        def error_message
          entry.error_message
        end

        def type_slug
          fetch? ? "fetch" : "scrape"
        end

        def fetch?
          entry.fetch?
        end

        def scrape?
          entry.scrape?
        end

        private

        attr_reader :entry, :url_helpers
      end

      def initialize(entries:, url_helpers:)
        @entries = entries
        @url_helpers = url_helpers
      end

      def rows
        entries.map { |entry| Row.new(entry, url_helpers) }
      end

      private

      attr_reader :entries, :url_helpers
    end
  end
end
