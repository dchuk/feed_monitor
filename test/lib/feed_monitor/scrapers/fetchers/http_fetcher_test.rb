# frozen_string_literal: true

require "test_helper"

module FeedMonitor
  module Scrapers
    module Fetchers
      class HttpFetcherTest < ActiveSupport::TestCase
        setup do
          @url = "https://example.com/articles/1"
          @fetcher = HttpFetcher.new
        end

        test "returns success result for 200 responses" do
          stub_request(:get, @url)
            .to_return(status: 200, body: "<html>ok</html>", headers: { "Content-Type" => "text/html" })

          result = @fetcher.fetch(url: @url, settings: { headers: {} })

          assert_equal :success, result.status
          assert_equal 200, result.http_status
          assert_includes result.body, "ok"
        end

        test "returns failure result for non-success status" do
          stub_request(:get, @url).to_return(status: 500, body: "error")

          result = @fetcher.fetch(url: @url, settings: {})

          assert_equal :failed, result.status
          assert_equal "Faraday::ServerError", result.error
          assert_includes result.message, "status 500"
        end

        test "captures faraday errors" do
          stub_request(:get, @url).to_raise(Faraday::ConnectionFailed.new("timeout"))

          result = @fetcher.fetch(url: @url, settings: {})

          assert_equal :failed, result.status
          assert_equal "Faraday::ConnectionFailed", result.error
          assert_equal "timeout", result.message
        end
      end
    end
  end
end
