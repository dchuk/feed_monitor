# frozen_string_literal: true

require "test_helper"

module FeedMonitor
  class ApplicationHelperTest < ActionView::TestCase
    include FeedMonitor::ApplicationHelper

    test "source_health_badge returns healthy styling" do
      source = FeedMonitor::Source.new(health_status: "healthy")

      badge = source_health_badge(source)

      assert_equal "Healthy", badge[:label]
      assert_match(/green/, badge[:classes])
    end

    test "source_health_badge indicates auto paused" do
      source = FeedMonitor::Source.new(health_status: "auto_paused")

      badge = source_health_badge(source)

      assert_equal "Auto-Paused", badge[:label]
      assert_match(/amber|rose/, badge[:classes])
    end
  end
end
