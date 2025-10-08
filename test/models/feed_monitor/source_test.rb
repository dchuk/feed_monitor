# frozen_string_literal: true

require "test_helper"

module FeedMonitor
  class SourceTest < ActiveSupport::TestCase
    test "is valid with minimal attributes" do
      source = Source.new(name: "Example", feed_url: "HTTPS://Example.com/Feed")

      assert source.valid?
    end

    test "normalizes feed and website URLs" do
      source = Source.create!(
        name: "Example",
        feed_url: "HTTPS://Example.COM",
        website_url: "http://Example.com"
      )

      assert_equal "https://example.com/", source.feed_url
      assert_equal "http://example.com/", source.website_url
    end

    test "rejects invalid feed URLs" do
      source = Source.new(name: "Bad", feed_url: "ftp://example.com/feed.xml")

      assert_not source.valid?
      assert_includes source.errors[:feed_url], "must be a valid HTTP(S) URL"
    end

    test "rejects malformed website URL" do
      source = Source.new(name: "Example", feed_url: "https://example.com/feed", website_url: "mailto:info@example.com")

      assert_not source.valid?
      assert_includes source.errors[:website_url], "must be a valid HTTP(S) URL"
    end

    test "enforces unique feed URLs" do
      Source.create!(name: "Example", feed_url: "https://example.com/feed")

      duplicate = Source.new(name: "Example 2", feed_url: "https://example.com/feed")

      assert_not duplicate.valid?
      assert_includes duplicate.errors[:feed_url], "has already been taken"
    end

    test "scopes reflect expected states" do
      healthy = Source.create!(name: "Healthy", feed_url: "https://example.com/healthy", next_fetch_at: 1.minute.ago)
      due_future = Source.create!(name: "Future", feed_url: "https://example.com/future", next_fetch_at: 10.minutes.from_now)
      inactive = Source.create!(name: "Inactive", feed_url: "https://example.com/inactive", active: false, next_fetch_at: 1.minute.ago)
      failed = Source.create!(
        name: "Failed",
        feed_url: "https://example.com/failed",
        failure_count: 2,
        last_error: "Timeout",
        last_error_at: 2.minutes.ago
      )

      assert_includes Source.active, healthy
      assert_not_includes Source.active, inactive

      assert_includes Source.due_for_fetch, healthy
      assert_not_includes Source.due_for_fetch, due_future

      assert_includes Source.failed, failed
      assert_not_includes Source.failed, healthy

      assert_includes Source.healthy, healthy
      assert_not_includes Source.healthy, failed
    end
  end
end
