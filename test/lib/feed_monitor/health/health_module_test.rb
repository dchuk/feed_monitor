# frozen_string_literal: true

require "test_helper"
require "ostruct"

module FeedMonitor
  module Health
    class HealthModuleTest < ActiveSupport::TestCase
      setup do
        FeedMonitor.reset_configuration!
      end

      test "registers fetch callback exactly once" do
        FeedMonitor::Health.setup!
        callbacks = FeedMonitor.config.events.callbacks_for(:after_fetch_completed)

        assert_includes callbacks, FeedMonitor::Health.fetch_callback

        FeedMonitor::Health.setup!
        callbacks_after = FeedMonitor.config.events.callbacks_for(:after_fetch_completed)

        assert_equal callbacks, callbacks_after
      end

      test "fetch callback invokes source health monitor" do
        source = create_source!
        monitor_calls = []

        FeedMonitor::Health.setup!

        FeedMonitor::Health::SourceHealthMonitor.stub(:new, ->(**) { monitor_calls << :invoked; Minitest::Mock.new.expect(:call, true) }) do
          FeedMonitor::Health.fetch_callback.call(OpenStruct.new(source: source))
        end

        assert_equal [ :invoked ], monitor_calls
      end
    end
  end
end
