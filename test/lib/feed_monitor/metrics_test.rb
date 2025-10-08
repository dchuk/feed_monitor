require "test_helper"

module FeedMonitor
  class MetricsTest < ActiveSupport::TestCase
    setup do
      FeedMonitor::Metrics.reset!
    end

    test "increment and gauge update snapshot" do
      FeedMonitor::Metrics.increment(:processed)
      FeedMonitor::Metrics.gauge(:in_flight, 3)

      snapshot = FeedMonitor::Metrics.snapshot

      assert_equal 1, snapshot[:counters]["processed"]
      assert_equal 3, snapshot[:gauges]["in_flight"]
    end

    test "fetch instrumentation updates metrics" do
      FeedMonitor::Instrumentation.fetch(source_id: 7, success: false) { sleep 0 }

      snapshot = FeedMonitor::Metrics.snapshot

      assert_equal 1, snapshot[:counters]["fetch_started_total"]
      assert_equal 1, snapshot[:counters]["fetch_finished_total"]
      assert_equal 1, snapshot[:counters]["fetch_failure_total"]
      assert_equal 0, snapshot[:counters]["fetch_success_total"]
      assert_equal 7, snapshot[:gauges]["last_fetch_source_id"]
      assert snapshot[:gauges]["last_fetch_duration_ms"].is_a?(Numeric)
    end
  end
end
