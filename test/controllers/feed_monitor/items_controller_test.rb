# frozen_string_literal: true

require "test_helper"

module FeedMonitor
  class ItemsControllerTest < ActionDispatch::IntegrationTest
    test "sanitizes search params before rendering" do
      get "/feed_monitor/items", params: {
        q: {
          "title_or_summary_or_url_or_source_name_cont" => "<img src=x onerror=alert(3)>"
        }
      }

      assert_response :success
      response_body = response.body
      refute_includes response_body, "%3Cimg"
      refute_includes response_body, "&lt;img"
    end
  end
end
