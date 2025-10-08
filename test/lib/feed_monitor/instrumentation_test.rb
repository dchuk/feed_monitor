require "test_helper"

module FeedMonitor
  class InstrumentationTest < ActiveSupport::TestCase
    setup do
      FeedMonitor::Metrics.reset!
    end

    test "fetch_start emits notification" do
      events = []
      ActiveSupport::Notifications.subscribed(->(_name, _start, _finish, _id, payload) { events << payload }, "feed_monitor.fetch.start") do
        FeedMonitor::Instrumentation.fetch_start(source_id: 42)
      end

      assert_equal 1, events.length
      assert_equal 42, events.first[:source_id]
    end

    test "fetch helper emits start and finish events" do
      start_events = 0
      finish_events = 0

      ActiveSupport::Notifications.subscribed(->(*_) { start_events += 1 }, "feed_monitor.fetch.start") do
        ActiveSupport::Notifications.subscribed(->(*_) { finish_events += 1 }, "feed_monitor.fetch.finish") do
          FeedMonitor::Instrumentation.fetch(success: true) { :done }
        end
      end

      assert_equal 1, start_events
      assert_equal 1, finish_events
    end
  end
end
