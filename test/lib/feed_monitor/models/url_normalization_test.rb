# frozen_string_literal: true

require "test_helper"

module FeedMonitor
  module Models
    class UrlNormalizationTest < ActiveSupport::TestCase
      test "normalizes source URLs using shared helper" do
        source = FeedMonitor::Source.new(
          name: "Example",
          feed_url: "HTTP://Example.com/Feed.xml ",
          website_url: "https://Example.com",
          scraper_adapter: "readability"
        )

        source.valid?

        assert_equal "http://example.com/Feed.xml", source.feed_url
        assert_equal "https://example.com/", source.website_url
      end

      test "normalizes item URL attributes consistently" do
        source = create_source!
        item = FeedMonitor::Item.new(
          source:,
          guid: "url-test",
          url: "HTTPS://Example.com/post ",
          canonical_url: "https://Example.com/post?ref=1",
          comments_url: "https://Example.com/post#comments"
        )

        assert item.valid?

        assert_equal "https://example.com/post", item.url
        assert_equal "https://example.com/post?ref=1", item.canonical_url
        assert_equal "https://example.com/post", item.comments_url
      end

      test "records invalid URL errors through helper" do
        source = FeedMonitor::Source.new(
          name: "Example",
          feed_url: "ftp://example.com/feed",
          scraper_adapter: "readability"
        )

        refute source.valid?
        assert_includes source.errors[:feed_url], "must be a valid HTTP(S) URL"
      end
    end
  end
end
