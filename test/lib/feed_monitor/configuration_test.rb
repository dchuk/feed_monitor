# frozen_string_literal: true

require "test_helper"

module FeedMonitor
  class ConfigurationTest < ActiveSupport::TestCase
    setup do
      FeedMonitor.reset_configuration!
    end

    teardown do
      FeedMonitor.reset_configuration!
    end

    test "mission control dashboard path resolves nil when route missing" do
      FeedMonitor.configure do |config|
        config.mission_control_dashboard_path = "/mission_control"
      end

      assert_nil FeedMonitor.mission_control_dashboard_path
    end

    test "mission control dashboard path resolves callable when route exists" do
      FeedMonitor.configure do |config|
        config.mission_control_dashboard_path = -> { FeedMonitor::Engine.routes.url_helpers.root_path }
      end

      assert_nothing_raised do
        Rails.application.routes.recognize_path(FeedMonitor::Engine.routes.url_helpers.root_path, method: :get)
      end

      assert_equal FeedMonitor::Engine.routes.url_helpers.root_path, FeedMonitor.mission_control_dashboard_path
    end

    test "mission control dashboard path allows external URLs" do
      FeedMonitor.configure do |config|
        config.mission_control_dashboard_path = "https://status.example.com/mission-control"
      end

      assert_equal "https://status.example.com/mission-control", FeedMonitor.mission_control_dashboard_path
    end
  end
end
