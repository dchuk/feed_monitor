# frozen_string_literal: true

require "test_helper"
require "minitest/mock"

module SourceMonitor
  class TurboBroadcasterTest < ActiveSupport::TestCase
    setup do
      SourceMonitor.reset_configuration!
      SourceMonitor::Dashboard::TurboBroadcaster.setup!
    end

    test "after_item_created triggers dashboard broadcast" do
      mock = Minitest::Mock.new
      mock.expect :call, nil

      SourceMonitor::Dashboard::TurboBroadcaster.stub :broadcast_dashboard_updates, -> { mock.call } do
        SourceMonitor::Events.after_item_created(item: nil, source: nil, entry: nil, result: nil)
      end

      assert_mock mock
    end

    test "after_fetch_completed triggers dashboard broadcast" do
      mock = Minitest::Mock.new
      mock.expect :call, nil

      SourceMonitor::Dashboard::TurboBroadcaster.stub :broadcast_dashboard_updates, -> { mock.call } do
        SourceMonitor::Events.after_fetch_completed(source: nil, result: nil)
      end

      assert_mock mock
    end
  end
end
