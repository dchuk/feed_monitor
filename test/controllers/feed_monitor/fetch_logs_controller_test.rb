# frozen_string_literal: true

require "test_helper"

module FeedMonitor
  class FetchLogsControllerTest < ActionDispatch::IntegrationTest
    setup do
      @source = create_source!
      @success_log = FeedMonitor::FetchLog.create!(
        source: @source,
        success: true,
        started_at: Time.current,
        http_status: 200
      )
      @failed_log = FeedMonitor::FetchLog.create!(
        source: @source,
        success: false,
        started_at: Time.current - 1.hour,
        http_status: 500
      )
    end

    test "filters by sanitized status parameter" do
      get "/feed_monitor/fetch_logs", params: { status: "success<script>" }

      assert_response :success

      assert_select "a[href='/feed_monitor/fetch_logs/#{@success_log.id}']", count: 1
      assert_select "a[href='/feed_monitor/fetch_logs/#{@failed_log.id}']", count: 0
    end

    test "falls back to all logs for invalid status" do
      get "/feed_monitor/fetch_logs", params: { status: "invalid" }

      assert_response :success

      assert_select "a[href='/feed_monitor/fetch_logs/#{@success_log.id}']", count: 1
      assert_select "a[href='/feed_monitor/fetch_logs/#{@failed_log.id}']", count: 1
    end
  end
end
