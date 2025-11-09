# frozen_string_literal: true

require "test_helper"

module SourceMonitor
  class ItemsControllerTest < ActionDispatch::IntegrationTest
    test "sanitizes search params before rendering" do
      get "/source_monitor/items", params: {
        q: {
          "title_or_summary_or_url_or_source_name_cont" => "<img src=x onerror=alert(3)>"
        }
      }

      assert_response :success
      response_body = response.body
      refute_includes response_body, "%3Cimg"
      refute_includes response_body, "&lt;img"
    end

    test "paginates items and ignores invalid page numbers" do
      source = create_source!
      items = Array.new(2) do |index|
        SourceMonitor::Item.create!(
          source: source,
          guid: SecureRandom.uuid,
          url: "https://example.com/articles/#{index}",
          title: "Item #{index}"
        )
      end

      get "/source_monitor/items", params: { page: "-5" }

      assert_response :success
      assert_includes response.body, items.last.title
    end
  end
end
