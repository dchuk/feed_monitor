require "test_helper"
require "uri"

module FeedMonitor
  module Fetching
    class FeedFetcherTest < ActiveSupport::TestCase
      setup do
        FeedMonitor::FetchLog.delete_all
        FeedMonitor::Source.delete_all
      end

      test "fetches an RSS feed and records log entries" do
        source = build_source(
          name: "RSS Sample",
          feed_url: "https://www.ruby-lang.org/en/feeds/news.rss"
        )

        result = nil
        VCR.use_cassette("feed_monitor/fetching/rss_success") do
          result = FeedFetcher.new(source: source).call
        end

        assert_equal :fetched, result.status
        assert_kind_of Feedjira::Parser::RSS, result.feed

        source.reload
        assert_equal 200, source.last_http_status
        assert_equal "rss", source.feed_format
        assert source.etag.present?

        log = source.fetch_logs.order(:created_at).last
        assert log.success
        assert_equal 200, log.http_status
        assert log.feed_size_bytes.positive?
        assert_equal result.feed.entries.size, log.items_in_feed
        assert_equal Feedjira::Parser::RSS.name, log.metadata["parser"]
      end

      test "reuses etag and handles 304 not modified responses" do
        feed_body = File.read(file_fixture("feeds/rss_sample.xml"))
        url = "https://example.com/rss.xml"

        source = build_source(name: "With ETag", feed_url: url)

        stub_request(:get, url)
          .to_return(
            status: 200,
            body: feed_body,
            headers: {
              "Content-Type" => "application/rss+xml",
              "ETag" => '"abcd1234"'
            }
          )

        result = FeedFetcher.new(source: source).call
        assert_equal :fetched, result.status

        source.reload
        assert_equal '"abcd1234"', source.etag

        stub_request(:get, url)
          .with(headers: { "If-None-Match" => '"abcd1234"' })
          .to_return(status: 304, headers: { "ETag" => '"abcd1234"' })

        second_result = FeedFetcher.new(source: source).call

        assert_equal :not_modified, second_result.status

        source.reload
        assert_equal 304, source.last_http_status
        assert_equal '"abcd1234"', source.etag

        log = source.fetch_logs.order(:created_at).last
        assert log.success
        assert_equal 304, log.http_status
        assert_nil log.items_in_feed
      end

      test "parses rss atom and json feeds via feedjira" do
        feeds = {
          rss:  {
            url: "https://www.ruby-lang.org/en/feeds/news.rss",
            parser: Feedjira::Parser::RSS
          },
          atom: {
            url: "https://go.dev/blog/feed.atom",
            parser: Feedjira::Parser::Atom
          },
          json: {
            url: "https://daringfireball.net/feeds/json",
            parser: Feedjira::Parser::JSONFeed
          }
        }

        feeds.each do |format, data|
          source = build_source(name: "#{format} feed", feed_url: data[:url])

          result = nil
          VCR.use_cassette("feed_monitor/fetching/#{format}_success") do
            result = FeedFetcher.new(source: source).call
          end

          assert_equal :fetched, result.status
          assert_kind_of data[:parser], result.feed
          expected_format = format == :json ? "json_feed" : format.to_s
          assert_equal expected_format, source.reload.feed_format
        end
      end

      private

      def build_source(name:, feed_url:)
        FeedMonitor::Source.create!(
          name: name,
          feed_url: feed_url,
          website_url: "https://#{URI.parse(feed_url).host}",
          fetch_interval_hours: 6
        )
      end
    end
  end
end
