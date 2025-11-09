# frozen_string_literal: true

require "test_helper"
require "source_monitor/items/retention_strategies/destroy"
require "source_monitor/items/retention_strategies/soft_delete"

module SourceMonitor
  module Items
    module RetentionStrategies
      class DestroyStrategyTest < ActiveSupport::TestCase
        test "destroy strategy removes items permanently" do
          source = create_source!
          items = Array.new(2) do |index|
            source.items.create!(
              guid: "destroy-#{index}",
              url: "https://example.com/destroy-#{index}",
              title: "Destroy #{index}"
            )
          end

          strategy = SourceMonitor::Items::RetentionStrategies::Destroy.new(source:)

          count = strategy.apply(batch: SourceMonitor::Item.where(id: items.map(&:id)), now: Time.current)

          assert_equal 2, count
          assert_equal 0, SourceMonitor::Item.where(id: items.map(&:id)).count
          assert_equal 0, source.reload.items_count
        end
      end

      class SoftDeleteStrategyTest < ActiveSupport::TestCase
        test "soft delete strategy marks items as deleted and updates counter cache" do
          source = create_source!
          items = Array.new(2) do |index|
            source.items.create!(
              guid: "soft-#{index}",
              url: "https://example.com/soft-#{index}",
              title: "Soft #{index}"
            )
          end

          strategy = SourceMonitor::Items::RetentionStrategies::SoftDelete.new(source:)

          timestamp = Time.zone.parse("2025-10-10 02:03:04 UTC")
          count = travel_to(timestamp) do
            strategy.apply(batch: SourceMonitor::Item.where(id: items.map(&:id)), now: timestamp)
          end

          assert_equal 2, count
          items.each do |item|
            reloaded = SourceMonitor::Item.with_deleted.find(item.id)
            assert reloaded.deleted?
            assert_in_delta timestamp, reloaded.deleted_at, 1.second
          end

          assert_equal 0, source.reload.items_count
        end
      end
    end
  end
end
