# frozen_string_literal: true

require "test_helper"

module FeedMonitor
  class ScrapeLogsControllerTest < ActionDispatch::IntegrationTest
    test "ignores non numeric identifiers when filtering" do
      get "/feed_monitor/scrape_logs", params: {
        item_id: "1<script>",
        source_id: "2><iframe",
        status: "<svg/onload=alert(4)>"
      }

      assert_response :success
      response_body = response.body
      refute_includes response_body, "%3Cscript"
      refute_includes response_body, "&lt;svg"
    end
  end
end
