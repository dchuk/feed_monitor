# frozen_string_literal: true

require "test_helper"
require "minitest/mock"

module FeedMonitor
  class TurboBroadcasterTest < ActiveSupport::TestCase
    setup do
      FeedMonitor.reset_configuration!
      FeedMonitor::Dashboard::TurboBroadcaster.setup!
    end

    test "after_item_created triggers dashboard broadcast" do
      mock = Minitest::Mock.new
      mock.expect :call, nil

      FeedMonitor::Dashboard::TurboBroadcaster.stub :broadcast_dashboard_updates, -> { mock.call } do
        FeedMonitor::Events.after_item_created(item: nil, source: nil, entry: nil, result: nil)
      end

      assert_mock mock
    end

    test "after_fetch_completed triggers dashboard broadcast" do
      mock = Minitest::Mock.new
      mock.expect :call, nil

      FeedMonitor::Dashboard::TurboBroadcaster.stub :broadcast_dashboard_updates, -> { mock.call } do
        FeedMonitor::Events.after_fetch_completed(source: nil, result: nil)
      end

      assert_mock mock
    end
  end
end
