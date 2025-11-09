# frozen_string_literal: true

require "test_helper"
require "minitest/mock"

module Feedmon
  class TurboBroadcasterTest < ActiveSupport::TestCase
    setup do
      Feedmon.reset_configuration!
      Feedmon::Dashboard::TurboBroadcaster.setup!
    end

    test "after_item_created triggers dashboard broadcast" do
      mock = Minitest::Mock.new
      mock.expect :call, nil

      Feedmon::Dashboard::TurboBroadcaster.stub :broadcast_dashboard_updates, -> { mock.call } do
        Feedmon::Events.after_item_created(item: nil, source: nil, entry: nil, result: nil)
      end

      assert_mock mock
    end

    test "after_fetch_completed triggers dashboard broadcast" do
      mock = Minitest::Mock.new
      mock.expect :call, nil

      Feedmon::Dashboard::TurboBroadcaster.stub :broadcast_dashboard_updates, -> { mock.call } do
        Feedmon::Events.after_fetch_completed(source: nil, result: nil)
      end

      assert_mock mock
    end
  end
end
