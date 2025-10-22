# frozen_string_literal: true

require "test_helper"

module FeedMonitor
  class LogEntryTest < ActiveSupport::TestCase
    test "detects health check log types" do
      source = create_source!
      health_log = FeedMonitor::HealthCheckLog.create!(
        source: source,
        success: true,
        started_at: Time.current,
        completed_at: Time.current,
        duration_ms: 100
      )

      entry = FeedMonitor::LogEntry.create!(
        source: source,
        loggable: health_log,
        started_at: health_log.started_at,
        success: true
      )

      assert entry.health_check?
      assert_equal :health_check, entry.log_type
      refute entry.fetch?
      refute entry.scrape?
    end
  end
end
