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
          assert created_item.metadata.present?, "metadata should include feedjira entry snapshot"
        end
      end

      test "extracts extended metadata from rss entry" do
        entry = parse_entry("feeds/rss_metadata_sample.xml")

        item = ItemCreator.call(source: @source, entry:)

        assert_equal "John Creator", item.author
        assert_equal ["jane@example.com (Jane Author)", "John Creator"], item.authors
        assert_equal ["Technology", "Ruby"], item.categories
        assert_equal ["Technology", "Ruby"], item.tags
        assert_equal ["feed monitoring", "rss"], item.keywords
        assert_equal "https://example.com/assets/thumb.jpg", item.media_thumbnail_url
        assert_equal(
          [
            {
              "url" => "https://example.com/assets/audio.mp3",
              "type" => "audio/mpeg",
              "length" => 67_890,
              "source" => "rss_enclosure"
            }
          ],
          item.enclosures
        )
        assert_equal(
          [
            {
              "url" => "https://example.com/assets/video.mp4",
              "type" => "video/mp4",
              "file_size" => 12_345
            }
          ],
          item.media_content
        )
        assert_equal "https://example.com/posts/1", item.comments_url
        assert_equal 12, item.comments_count
        assert_equal "Rich Hello World", item.title
        assert_equal "<p>First item content.</p>", item.content
        assert_equal "First item content.", item.summary

        metadata = item.metadata.fetch("feedjira_entry")
        assert_equal "Rich Hello World", metadata["title"]
        assert_equal "https://example.com/posts/1", metadata["url"]
      end

      test "captures json feed authors tags and attachments" do
        entry = parse_entry("feeds/json_feed_sample.json")

        item = ItemCreator.call(source: @source, entry:)

        assert_equal "JSON Primary Author", item.author
        assert_equal ["JSON Primary Author", "JSON Secondary Author"], item.authors
        assert_equal ["JSON", "Feeds"], item.categories
        assert_equal ["JSON", "Feeds"], item.tags
        assert_equal(
          [
            {
              "url" => "https://example.com/media/podcast.mp3",
              "type" => "audio/mpeg",
              "length" => 123_456,
              "duration" => 3_600,
              "title" => "Podcast Episode 1",
              "source" => "json_feed_attachment"
            }
          ],
          item.enclosures
        )
        assert_nil item.media_thumbnail_url
        assert_equal [], item.media_content
        assert_equal "en-US", item.language
        assert_equal "Copyright 2025 Example", item.copyright
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
