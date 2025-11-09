require "test_helper"

module Feedmon
  class EngineMountingTest < ActionDispatch::IntegrationTest
    test "host app routes mount the engine at /feedmon" do
      helpers = Rails.application.routes.url_helpers
      assert_respond_to helpers, :feedmon_path
      assert_equal "/feedmon", helpers.feedmon_path
    end

    test "engine root responds with welcome content" do
      get "/feedmon"
      assert_response :success
      assert_match "Feedmon", response.body
    end
  end
end
