# frozen_string_literal: true

require "test_helper"
require "ostruct"

module SourceMonitor
  module Health
    class HealthModuleTest < ActiveSupport::TestCase
      setup do
        SourceMonitor.reset_configuration!
      end

      test "registers fetch callback exactly once" do
        SourceMonitor::Health.setup!
        callbacks = SourceMonitor.config.events.callbacks_for(:after_fetch_completed)

        assert_includes callbacks, SourceMonitor::Health.fetch_callback

        SourceMonitor::Health.setup!
        callbacks_after = SourceMonitor.config.events.callbacks_for(:after_fetch_completed)

        assert_equal callbacks, callbacks_after
      end

      test "fetch callback invokes source health monitor" do
        source = create_source!
        monitor_calls = []

        SourceMonitor::Health.setup!

        SourceMonitor::Health::SourceHealthMonitor.stub(:new, ->(**) { monitor_calls << :invoked; Minitest::Mock.new.expect(:call, true) }) do
          SourceMonitor::Health.fetch_callback.call(OpenStruct.new(source: source))
        end

        assert_equal [ :invoked ], monitor_calls
      end
    end
  end
end
