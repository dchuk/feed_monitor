# frozen_string_literal: true

require "test_helper"

module Feedmon
  class ModelExtensionsTest < ActiveSupport::TestCase
    test "table name prefix defaults to feedmon_" do
      assert_equal "feedmon_", Feedmon.table_name_prefix
      assert_equal "feedmon_sources", Feedmon::Source.table_name
    end

    test "table name prefix can be overridden through configuration" do
      Feedmon.configure do |config|
        config.models.table_name_prefix = "custom_feedmon_"
      end

      assert_equal "custom_feedmon_", Feedmon.table_name_prefix
      assert_equal "custom_feedmon_sources", Feedmon::Source.table_name
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

      Feedmon.configure do |config|
        config.models.source.include_concern(concern)
      end

      source = Feedmon::Source.new(
        name: "Concern Source",
        feed_url: "https://example.com/feed.xml",
        fetch_interval_minutes: 60,
        scraper_adapter: "readability"
      )

      assert_respond_to source, :extension_flag=
      assert source.extension_behavior?
    end

    test "configured validation blocks run for models" do
      Feedmon.configure do |config|
        config.models.source.validate ->(record) {
          record.errors.add(:base, "custom validation hit")
        }
      end

      source = Feedmon::Source.new(
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

      Feedmon.configure do |config|
        config.models.source.include_concern(concern)
        config.models.source.validate :ensure_custom_state
      end

      source = Feedmon::Source.new(
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
