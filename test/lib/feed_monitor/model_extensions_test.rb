# frozen_string_literal: true

require "test_helper"

module FeedMonitor
  class ModelExtensionsTest < ActiveSupport::TestCase
    setup do
      FeedMonitor.reset_configuration!
    end

    teardown do
      FeedMonitor.reset_configuration!
    end

    test "table name prefix defaults to feed_monitor_" do
      assert_equal "feed_monitor_", FeedMonitor.table_name_prefix
      assert_equal "feed_monitor_sources", FeedMonitor::Source.table_name
    end

    test "table name prefix can be overridden through configuration" do
      FeedMonitor.configure do |config|
        config.models.table_name_prefix = "custom_feed_monitor_"
      end

      assert_equal "custom_feed_monitor_", FeedMonitor.table_name_prefix
      assert_equal "custom_feed_monitor_sources", FeedMonitor::Source.table_name
    end

    test "configured concerns are mixed into models" do
      concern = Module.new do
        extend ActiveSupport::Concern

        included do
          attr_accessor :extension_flag
        end

        def extension_behavior?
          true
        end
      end

      FeedMonitor.configure do |config|
        config.models.source.include_concern(concern)
      end

      source = FeedMonitor::Source.new(
        name: "Concern Source",
        feed_url: "https://example.com/feed.xml",
        fetch_interval_minutes: 60,
        scraper_adapter: "readability"
      )

      assert_respond_to source, :extension_flag=
      assert source.extension_behavior?
    end

    test "configured validation blocks run for models" do
      FeedMonitor.configure do |config|
        config.models.source.validate ->(record) {
          record.errors.add(:base, "custom validation hit")
        }
      end

      source = FeedMonitor::Source.new(
        name: "Validation Source",
        feed_url: "https://example.com/feed.xml",
        fetch_interval_minutes: 60,
        scraper_adapter: "readability"
      )

      refute source.valid?
      assert_includes source.errors[:base], "custom validation hit"
    end

    test "configured validation methods run for models" do
      concern = Module.new do
        extend ActiveSupport::Concern

        def ensure_custom_state
          errors.add(:base, "method validation hit")
        end
      end

      FeedMonitor.configure do |config|
        config.models.source.include_concern(concern)
        config.models.source.validate :ensure_custom_state
      end

      source = FeedMonitor::Source.new(
        name: "Method Validation Source",
        feed_url: "https://example.com/feed.xml",
        fetch_interval_minutes: 60,
        scraper_adapter: "readability"
      )

      refute source.valid?
      assert_includes source.errors[:base], "method validation hit"
    end
  end
end
