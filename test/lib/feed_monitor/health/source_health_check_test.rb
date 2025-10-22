# frozen_string_literal: true

require "test_helper"

module FeedMonitor
  module Health
    class SourceHealthCheckTest < ActiveSupport::TestCase
      setup do
        FeedMonitor::HealthCheckLog.delete_all
        FeedMonitor::Source.delete_all
        @source = create_source!(feed_url: "https://example.com/check.xml")
      end

      test "records successful health check with response metadata" do
        stub_request(:get, @source.feed_url).to_return(
          status: 204,
          body: "",
          headers: { "X-Feed-Header" => "present" }
        )

        result = FeedMonitor::Health::SourceHealthCheck.new(source: @source).call

        assert result.success?
        assert_nil result.error
        log = result.log
        assert_equal @source, log.source
        assert_equal 204, log.http_status
        assert_equal "present", log.http_response_headers["X-Feed-Header"] || log.http_response_headers["x-feed-header"]
      end

      test "records failure when request raises and captures error details" do
        stub_request(:get, @source.feed_url).to_timeout

        result = FeedMonitor::Health::SourceHealthCheck.new(source: @source).call

        refute result.success?
        assert_kind_of StandardError, result.error

        log = result.log
        refute log.success?
        assert_equal @source, log.source
        assert_nil log.http_status
        assert_match(/expired|timeout/i, log.error_message.to_s)
      end
    end
  end
end
