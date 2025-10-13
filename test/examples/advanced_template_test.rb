# frozen_string_literal: true

require "test_helper"

module FeedMonitor
  class AdvancedTemplateTest < ActiveSupport::TestCase
    TEMPLATE_PATH = FeedMonitor::Engine.root.join("examples/advanced_host/template.rb")

    test "template enables mission control and redis realtime" do
      source = TEMPLATE_PATH.read

      assert_includes source, 'gem "mission_control-jobs"', "expected Mission Control dependency"
      assert_includes source, 'config.mission_control_enabled = true', "expected initializer tweaks"
      assert_includes source, 'config.realtime.adapter = :redis', "expected realtime adapter override"
    end

    test "template copies instrumentation initializer" do
      source = TEMPLATE_PATH.read

      assert_includes source, 'feed_monitor_instrumentation.rb', "expected instrumentation initializer to be copied"
    end
  end
end
