require "test_helper"

module FeedMonitor
  class EngineMountingTest < ActionDispatch::IntegrationTest
    test "host app routes mount the engine at /feed_monitor" do
      helpers = Rails.application.routes.url_helpers
      assert_respond_to helpers, :feed_monitor_path
      assert_equal "/feed_monitor", helpers.feed_monitor_path
    end

    test "engine root responds with welcome content" do
      get "/feed_monitor"
      assert_response :success
      assert_match "Feed Monitor", response.body
    end
  end
end
