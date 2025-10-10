require "test_helper"
require "securerandom"
require "feed_monitor/items/retention_pruner"

module FeedMonitor
  module Items
    class RetentionPrunerTest < ActiveSupport::TestCase
      setup do
        FeedMonitor::Item.delete_all
        FeedMonitor::Source.delete_all
      end

      test "removes items older than the configured retention period" do
        source = build_source(items_retention_days: 7)

        travel_to Time.zone.local(2025, 10, 1, 12, 0, 0) do
          create_item(source:, guid: "old", published_at: Time.current, title: "Old post")
        end

        travel_to Time.zone.local(2025, 10, 10, 12, 0, 0) do
          create_item(source:, guid: "recent", published_at: Time.current, title: "Recent post")

          result = FeedMonitor::Items::RetentionPruner.call(source:)
          assert_equal 1, result.removed_by_age
          assert_equal 0, result.removed_by_limit
          assert_equal ["recent"], source.items.pluck(:guid)
        end
      end

      test "uses created_at when published_at is missing" do
        source = build_source(items_retention_days: 3)

        travel_to Time.zone.local(2025, 10, 1, 12, 0, 0) do
          create_item(source:, guid: "stale", published_at: nil, title: "Scheduled later")
        end

        travel_to Time.zone.local(2025, 10, 4, 12, 0, 0) do
          create_item(source:, guid: "fresh", published_at: nil, title: "Recent item")

          result = FeedMonitor::Items::RetentionPruner.call(source:)
          assert_equal 1, result.removed_by_age
          assert_equal ["fresh"], source.items.pluck(:guid)
        end
      end

      test "enforces maximum item count by trimming oldest records" do
        source = build_source(max_items: 2)

        create_item(source:, guid: "one", published_at: 4.days.ago, title: "First")
        create_item(source:, guid: "two", published_at: 3.days.ago, title: "Second")
        create_item(source:, guid: "three", published_at: 2.days.ago, title: "Third")

        result = FeedMonitor::Items::RetentionPruner.call(source:)
        assert_equal 0, result.removed_by_age
        assert_equal 1, result.removed_by_limit

        remaining = source.items.order(Arel.sql("published_at DESC NULLS LAST, created_at DESC")).pluck(:guid)
        assert_equal %w[three two], remaining
      end

      test "fires instrumentation when retention removes records" do
        source = build_source(items_retention_days: 5, max_items: 2)

        travel_to Time.zone.local(2025, 9, 20, 12, 0, 0) do
          create_item(source:, guid: "very-old", published_at: Time.current, title: "Very old")
          create_item(source:, guid: "old", published_at: Time.current, title: "Old")
        end

        create_item(source:, guid: "current-1", published_at: 2.days.ago, title: "Fresh A")
        create_item(source:, guid: "current-2", published_at: 1.day.ago, title: "Fresh B")
        create_item(source:, guid: "current-3", published_at: Time.current, title: "Fresh C")

        events = []
        subscriber = ActiveSupport::Notifications.subscribe(FeedMonitor::Instrumentation::ITEM_RETENTION_EVENT) do |_name, _start, _finish, _id, payload|
          events << payload
        end

        result = FeedMonitor::Items::RetentionPruner.call(source:)

        assert_equal 2, result.removed_by_age
        assert_equal 1, result.removed_by_limit
        assert_equal 3, result.removed_total

        assert_equal 1, events.size
        payload = events.first
        assert_equal source.id, payload[:source_id]
        assert_equal 2, payload[:removed_by_age]
        assert_equal 1, payload[:removed_by_limit]
        assert_equal 3, payload[:removed_total]
        assert_equal 5, payload[:items_retention_days]
        assert_equal 2, payload[:max_items]
      ensure
        ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
      end

      test "supports soft delete strategy" do
        source = build_source(items_retention_days: 1)

        travel_to Time.zone.local(2025, 10, 1, 12, 0, 0) do
          create_item(source:, guid: "stale", published_at: Time.current, title: "Stale")
        end

        travel_to Time.zone.local(2025, 10, 4, 12, 0, 0) do
          result = FeedMonitor::Items::RetentionPruner.call(source:, strategy: :soft_delete)
          assert_equal 1, result.removed_total

          stale = source.all_items.with_deleted.find_by(guid: "stale")
          assert stale.deleted?
          assert_equal 0, source.reload.items_count
        end
      end

      private

      def build_source(attributes = {})
        defaults = {
          name: "Source #{SecureRandom.hex(4)}",
          feed_url: "https://example.com/#{SecureRandom.hex(8)}.xml",
          fetch_interval_minutes: 60
        }

        FeedMonitor::Source.create!(defaults.merge(attributes))
      end

      def create_item(source:, guid:, published_at:, title:)
        source.items.create!(
          guid: guid,
          url: "https://example.com/#{guid}",
          title: title,
          published_at: published_at,
          summary: "Summary for #{title}"
        )
      end
    end
  end
end
