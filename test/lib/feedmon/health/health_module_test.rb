# frozen_string_literal: true

require "test_helper"
require "ostruct"

module Feedmon
  module Health
    class HealthModuleTest < ActiveSupport::TestCase
      setup do
        Feedmon.reset_configuration!
      end

      test "registers fetch callback exactly once" do
        Feedmon::Health.setup!
        callbacks = Feedmon.config.events.callbacks_for(:after_fetch_completed)

        assert_includes callbacks, Feedmon::Health.fetch_callback

        Feedmon::Health.setup!
        callbacks_after = Feedmon.config.events.callbacks_for(:after_fetch_completed)

        assert_equal callbacks, callbacks_after
      end

      test "fetch callback invokes source health monitor" do
        source = create_source!
        monitor_calls = []

        Feedmon::Health.setup!

        Feedmon::Health::SourceHealthMonitor.stub(:new, ->(**) { monitor_calls << :invoked; Minitest::Mock.new.expect(:call, true) }) do
          Feedmon::Health.fetch_callback.call(OpenStruct.new(source: source))
        end

        assert_equal [ :invoked ], monitor_calls
      end
    end
  end
end
