# frozen_string_literal: true

require "test_helper"

module SourceMonitor
  class ItemScopeTest < ActiveSupport::TestCase
    setup do
      @source = Source.create!(name: "Test Source", feed_url: "https://example.com/feed")
      @active_item = Item.create!(
        source: @source,
        guid: "active-123",
        url: "https://example.com/active"
      )
      @deleted_item = Item.create!(
        source: @source,
        guid: "deleted-456",
        url: "https://example.com/deleted"
      )
      @deleted_item.soft_delete!
    end

    test ".active scope excludes soft-deleted items" do
      active_items = Item.active

      assert_includes active_items, @active_item
      assert_not_includes active_items, @deleted_item
    end

    test ".with_deleted scope includes all items" do
      all_items = Item.with_deleted

      assert_includes all_items, @active_item
      assert_includes all_items, @deleted_item
    end

    test ".only_deleted scope shows only soft-deleted items" do
      deleted_items = Item.only_deleted

      assert_not_includes deleted_items, @active_item
      assert_includes deleted_items, @deleted_item
    end

    test "Item.all without scope should return all items including deleted" do
      # After removing default_scope, Item.all should return everything
      all_items = Item.all

      assert_includes all_items, @active_item
      assert_includes all_items, @deleted_item
    end

    test "scopes chain properly with .active" do
      published_item = Item.create!(
        source: @source,
        guid: "published-789",
        url: "https://example.com/published",
        published_at: 1.hour.ago
      )
      published_item.soft_delete!

      active_published = Item.active.published

      assert_not_includes active_published, published_item
    end

    test "Source#items association excludes soft-deleted items" do
      source_items = @source.items

      assert_includes source_items, @active_item
      assert_not_includes source_items, @deleted_item
    end

    test "Source#all_items association includes soft-deleted items" do
      all_source_items = @source.all_items

      assert_includes all_source_items, @active_item
      assert_includes all_source_items, @deleted_item
    end
  end
end
