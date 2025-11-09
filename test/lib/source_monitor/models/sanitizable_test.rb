# frozen_string_literal: true

require "test_helper"

module SourceMonitor
  module Models
    class SanitizableTest < ActiveSupport::TestCase
      test "sanitizes configured string attributes before validation" do
        source = SourceMonitor::Source.new(
          name: "<script>alert(1)</script> News",
          feed_url: "https://example.com/feed.xml",
          website_url: "https://example.com",
          scraper_adapter: "<b>custom</b>"
        )

        source.valid?

        assert_equal "alert(1) News", source.name
        assert_equal "custom", source.scraper_adapter
      end

      test "sanitizes configured hash attributes deeply" do
        source = SourceMonitor::Source.new(
          name: "Example",
          feed_url: "https://example.com/feed.xml",
          website_url: "https://example.com",
          scrape_settings: {
            selectors: [ "<script>main</script>", { teaser: "<div>Lead</div>" } ]
          },
          metadata: { "<script>" => "<b>value</b>" }
        )

        source.valid?

        selectors = source.scrape_settings["selectors"]
        assert selectors.present?
        assert_equal "main", selectors.first
        assert_equal "Lead", selectors.last["teaser"]
        assert_equal "value", source.metadata["<script>"]
      end
    end
  end
end
