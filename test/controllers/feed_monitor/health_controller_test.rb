require "test_helper"

module FeedMonitor
  class HealthControllerTest < ActionDispatch::IntegrationTest
    setup do
      FeedMonitor::Metrics.reset!
    end

    test "returns ok status with metrics snapshot" do
      FeedMonitor::Instrumentation.fetch_start(source_id: 10)

      get "/feed_monitor/health"

      assert_response :success

      body = JSON.parse(response.body)
      assert_equal "ok", body["status"]
      assert_equal 10, body.dig("metrics", "gauges", "last_fetch_source_id")
    end
  end
end
