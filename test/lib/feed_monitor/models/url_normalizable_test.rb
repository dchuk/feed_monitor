# frozen_string_literal: true

require "test_helper"
require "feed_monitor/models/url_normalizable"

module FeedMonitor
  module Models
    class UrlNormalizableTest < ActiveSupport::TestCase
      # Test using actual models that include the concern

      test "Source model uses validates_url_format correctly" do
        source = Source.new(name: "Test", feed_url: "ftp://invalid.com")

        assert_not source.valid?
        assert_includes source.errors[:feed_url], "must be a valid HTTP(S) URL"
      end

      test "Item model uses validates_url_format correctly" do
        source = Source.create!(name: "Test Source", feed_url: "https://example.com/feed")
        item = Item.new(
          source: source,
          guid: "test-123",
          url: "mailto:bad@example.com"
        )

        assert_not item.valid?
        assert_includes item.errors[:url], "must be a valid HTTP(S) URL"
      end

      test "validates_url_format allows blank values" do
        source = Source.create!(name: "Test Source", feed_url: "https://example.com/feed")
        item = Item.new(
          source: source,
          guid: "test-456",
          url: "https://example.com/article",
          canonical_url: nil  # blank URL should be allowed
        )

        assert item.valid?
      end
    end
  end
end
