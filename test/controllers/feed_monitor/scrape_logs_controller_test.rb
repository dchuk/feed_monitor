# frozen_string_literal: true

require "test_helper"

module FeedMonitor
  class ScrapeLogsControllerTest < ActionDispatch::IntegrationTest
    setup do
      @source = create_source!
      @item = FeedMonitor::Item.create!(
        source: @source,
        guid: SecureRandom.uuid,
        url: "https://example.com/articles/primary",
        title: "Primary"
      )
      @other_item = FeedMonitor::Item.create!(
        source: @source,
        guid: SecureRandom.uuid,
        url: "https://example.com/articles/other",
        title: "Other"
      )

      @success_log = FeedMonitor::ScrapeLog.create!(
        source: @source,
        item: @item,
        success: true,
        started_at: Time.current
      )

      @failed_log = FeedMonitor::ScrapeLog.create!(
        source: @source,
        item: @other_item,
        success: false,
        started_at: Time.current - 30.minutes
      )
    end

    test "filters by item and sanitized status" do
      get "/feed_monitor/scrape_logs", params: {
        item_id: @item.id.to_s,
        status: "success<script>"
      }

      assert_response :success
      assert_includes response.body, @item.title
      refute_includes response.body, @other_item.title
    end

    test "ignores invalid identifiers and status" do
      get "/feed_monitor/scrape_logs", params: {
        item_id: "1<script>",
        source_id: "2><iframe",
        status: "<svg/onload=alert(4)>"
      }

      assert_response :success
      assert_includes response.body, @item.title
      assert_includes response.body, @other_item.title
    end
  end
end
