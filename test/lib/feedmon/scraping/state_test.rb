# frozen_string_literal: true

require "test_helper"
require "securerandom"

module Feedmon
  module Scraping
    class StateTest < ActiveSupport::TestCase
      setup do
        Feedmon::Item.delete_all
        Feedmon::Source.delete_all
      end

      test "mark_pending sets the item to pending without broadcast" do
        source = create_source
        item = create_item(source:)

        Feedmon::Realtime.stub(:broadcast_item, ->(_item) { flunk("should not broadcast") }) do
          Feedmon::Scraping::State.mark_pending!(item, broadcast: false)
        end

        assert_equal "pending", item.reload.scrape_status
      end

      test "mark_processing sets processing and broadcasts" do
        source = create_source
        item = create_item(source:)

        broadcasted = false
        Feedmon::Realtime.stub(:broadcast_item, ->(broadcast_item) { broadcasted = broadcast_item == item }) do
          Feedmon::Scraping::State.mark_processing!(item)
        end

        item.reload
        assert_equal "processing", item.scrape_status
        assert broadcasted
      end

      test "clear_inflight resets status when in flight" do
        source = create_source
        item = create_item(source:)
        item.update!(scrape_status: "processing")

        Feedmon::Scraping::State.clear_inflight!(item)

        assert_nil item.reload.scrape_status
      end

      test "clear_inflight leaves status when not in flight" do
        source = create_source
        item = create_item(source:)
        item.update!(scrape_status: "success")

        Feedmon::Scraping::State.clear_inflight!(item)

        assert_equal "success", item.reload.scrape_status
      end

      private

      def create_source
        create_source!(scraping_enabled: true, auto_scrape: true)
      end

      def create_item(source:)
        Feedmon::Item.create!(
          source: source,
          guid: SecureRandom.uuid,
          url: "https://example.com/#{SecureRandom.hex}",
          title: "Item"
        )
      end
    end
  end
end
