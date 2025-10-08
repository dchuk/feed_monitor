require "test_helper"
require "digest"

module FeedMonitor
  module Items
    class ItemCreatorTest < ActiveSupport::TestCase
      setup do
        FeedMonitor::Item.delete_all
        FeedMonitor::Source.delete_all
        @source = build_source
      end

      test "creates item from rss entry and computes fingerprint" do
        entry = parse_entry("feeds/rss_sample.xml")
        entry.url = "HTTPS://EXAMPLE.COM/posts/1#fragment"

        item = ItemCreator.call(source: @source, entry:)

        assert item.persisted?, "item should be saved"
        assert_equal @source, item.source
        assert_equal "https://example.com/posts/1", item.url
        assert_equal item.url, item.canonical_url

        expected_fingerprint = Digest::SHA256.hexdigest(
          [
            entry.title.strip,
            entry.url.strip,
            entry.summary.strip
          ].join("\u0000")
        )
        assert_equal expected_fingerprint, item.content_fingerprint
      end

      test "falls back to fingerprint when entry provides no guid" do
        entry = parse_entry("feeds/rss_no_guid.xml")

        item = ItemCreator.call(source: @source, entry:)

        assert item.persisted?
        assert_equal item.content_fingerprint, item.guid
      end

      test "creates items from rss atom and json feeds" do
        fixtures = {
          rss: "feeds/rss_sample.xml",
          atom: "feeds/atom_sample.xml",
          json: "feeds/json_feed_sample.json"
        }

        fixtures.each_value do |fixture|
          entry = parse_entry(fixture)
          created_item = ItemCreator.call(source: @source, entry:)

          assert created_item.persisted?
          assert created_item.guid.present?
          assert created_item.content_fingerprint.present?
          assert_equal created_item.url, created_item.canonical_url
          assert_equal entry.title.strip, created_item.title if entry.respond_to?(:title) && entry.title.present?
          assert_includes [Time, ActiveSupport::TimeWithZone, DateTime, NilClass], created_item.published_at.class
        end
      end

      private

      def build_source
        FeedMonitor::Source.create!(
          name: "Example Source",
          feed_url: "https://example.com/feed.xml",
          website_url: "https://example.com",
          fetch_interval_minutes: 60
        )
      end

      def parse_entry(fixture)
        data = File.read(file_fixture(fixture))
        Feedjira.parse(data).entries.first
      end
    end
  end
end
