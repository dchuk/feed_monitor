# frozen_string_literal: true

require "test_helper"

module Feedmon
  class LogsControllerTest < ActionDispatch::IntegrationTest
    setup do
      @source = create_source!(name: "Controller Source")

      @item = Feedmon::Item.create!(
        source: @source,
        guid: SecureRandom.uuid,
        title: "Controller Item",
        url: "https://example.com/items/controller"
      )

      @fetch_success = Feedmon::FetchLog.create!(
        source: @source,
        success: true,
        http_status: 200,
        items_created: 1,
        items_updated: 0,
        items_failed: 0,
        started_at: Time.current - 2.hours,
        error_message: "OK"
      )

      @scrape_failure = Feedmon::ScrapeLog.create!(
        source: @source,
        item: @item,
        success: false,
        scraper_adapter: "readability",
        http_status: 500,
        started_at: Time.current - 1.hour,
        error_message: "Timed out parsing"
      )
    end

    test "filters by sanitized status and log type parameters" do
      get "/feedmon/logs", params: { status: "failed<script>", log_type: "scrape<script>" }

      assert_response :success
      assert_includes response.body, "data-log-row=\"scrape-#{@scrape_failure.id}\""
      refute_includes response.body, "data-log-row=\"fetch-#{@fetch_success.id}\""
    end

    test "applies sanitized search parameter" do
      get "/feedmon/logs", params: { search: "OK<script>" }

      assert_response :success
      assert_includes response.body, "data-log-row=\"fetch-#{@fetch_success.id}\""
      refute_includes response.body, "data-log-row=\"scrape-#{@scrape_failure.id}\""
    end

    test "ignores invalid timeframe and source filters" do
      get "/feedmon/logs", params: {
        timeframe: "bogus<script>",
        source_id: "1; DROP TABLE",
        started_after: "not-a-date",
        started_before: "<svg>"
      }

      assert_response :success
      assert_includes response.body, "data-log-row=\"fetch-#{@fetch_success.id}\""
      assert_includes response.body, "data-log-row=\"scrape-#{@scrape_failure.id}\""
    end
  end
end
