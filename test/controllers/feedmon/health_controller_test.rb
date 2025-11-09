require "test_helper"

module Feedmon
  class HealthControllerTest < ActionDispatch::IntegrationTest
    setup do
      Feedmon::Metrics.reset!
    end

    test "returns ok status with metrics snapshot" do
      Feedmon::Instrumentation.fetch_start(source_id: 10)

      get "/feedmon/health"

      assert_response :success

      body = JSON.parse(response.body)
      assert_equal "ok", body["status"]
      assert_equal 10, body.dig("metrics", "gauges", "last_fetch_source_id")
    end
  end
end
