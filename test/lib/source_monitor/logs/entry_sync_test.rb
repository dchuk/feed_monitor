# frozen_string_literal: true

require "test_helper"

module SourceMonitor
  module Logs
    class EntrySyncTest < ActiveSupport::TestCase
      test "returns nil when loggable is not persisted" do
        log = SourceMonitor::FetchLog.new

        assert_nil SourceMonitor::Logs::EntrySync.call(log)
      end

      test "syncs attributes to an existing log entry" do
        source = create_source!(scraping_enabled: true, auto_scrape: true)
        item = SourceMonitor::Item.create!(
          source:,
          guid: "entry-sync",
          url: "https://example.com/items/entry-sync",
          title: "Entry Sync Test"
        )

        log = SourceMonitor::ScrapeLog.create!(
          source:,
          item:,
          started_at: Time.current,
          completed_at: Time.current,
          success: false,
          http_status: 504,
          duration_ms: 1250,
          scraper_adapter: "readability",
          content_length: 8192,
          error_class: "TimeoutError",
          error_message: "Fetch timed out"
        )

        SourceMonitor::Logs::EntrySync.call(log)
        entry = log.log_entry

        assert entry.persisted?, "expected log entry to be saved"
        assert_equal source, entry.source
        assert_equal item, entry.item
        refute entry.success
        assert_equal 504, entry.http_status
        assert_equal 1250, entry.duration_ms
        assert_equal "TimeoutError", entry.error_class
        assert_equal "Fetch timed out", entry.error_message
      end

      test "rescues persistence failures and returns nil" do
        source = create_source!
        loggable = DummyLoggable.new(source:)

        assert_nil SourceMonitor::Logs::EntrySync.call(loggable)
      end

      class DummyLoggable
        attr_reader :source, :started_at

        def initialize(source:)
          @source = source
          @started_at = Time.current
        end

        def id
          42
        end

        def persisted?
          true
        end

        def log_entry
          nil
        end

        def build_log_entry
          RaisingLogEntry.new
        end

        def success
          nil
        end
      end

      class RaisingLogEntry
        def assign_attributes(_attributes)
          # no-op
        end

        def save!
          raise ActiveRecord::RecordNotSaved.new("boom")
        end
      end
    end
  end
end
