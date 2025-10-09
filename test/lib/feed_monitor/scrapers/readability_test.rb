# frozen_string_literal: true

require "test_helper"

module FeedMonitor
  module Scrapers
    class ReadabilityTest < ActiveSupport::TestCase
      setup do
        @url = "https://example.com/articles/1"
        @html = file_fixture("articles/readability_sample.html").read
      end

      test "extracts article content using readability fallback" do
        stub_request(:get, @url)
          .to_return(status: 200, body: @html, headers: { "Content-Type" => "text/html; charset=utf-8" })

        item = FeedMonitor::Item.new(url: @url)
        source = FeedMonitor::Source.new

        result = FeedMonitor::Scrapers::Readability.call(item:, source:)

        assert_equal :success, result.status
        assert_includes result.html, "<article id=\"post\""
        assert_includes result.content, "Paragraph one introduces the topic"
        assert_equal 200, result.metadata[:http_status]
        assert_equal :readability, result.metadata[:extraction_strategy]
        assert_equal "Sample Article Title", result.metadata[:title]
      end

      test "honors custom CSS selectors from source settings" do
        stub_request(:get, @url)
          .to_return(status: 200, body: @html, headers: { "Content-Type" => "text/html; charset=utf-8" })

        source = FeedMonitor::Source.new(
          scrape_settings: {
            selectors: {
              content: ".custom-body",
              title: ".headline"
            }
          }
        )

        result = FeedMonitor::Scrapers::Readability.call(
          item: FeedMonitor::Item.new(url: @url),
          source: source
        )

        assert_equal :success, result.status
        assert_equal :selectors, result.metadata[:extraction_strategy]
        assert_includes result.content, "Custom selector text"
        assert_equal "Sample Article Title", result.metadata[:title]
      end

      test "returns failure result when http response is not successful" do
        stub_request(:get, @url)
          .to_return(status: 500, body: "oops")

        result = FeedMonitor::Scrapers::Readability.call(
          item: FeedMonitor::Item.new(url: @url),
          source: FeedMonitor::Source.new
        )

        assert_equal :failed, result.status
        assert_nil result.html
        assert_nil result.content
        assert_equal 500, result.metadata[:http_status]
        assert_equal "Faraday::ServerError", result.metadata[:error]
      end
    end
  end
end
