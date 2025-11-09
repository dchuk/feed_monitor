# frozen_string_literal: true

require "test_helper"

module Feedmon
  class ConfigurationTest < ActiveSupport::TestCase
    setup do
      Feedmon.reset_configuration!
    end

    teardown do
      Feedmon.reset_configuration!
    end

    test "mission control dashboard path resolves nil when route missing" do
      Feedmon.configure do |config|
        config.mission_control_dashboard_path = "/mission_control"
      end

      assert_nil Feedmon.mission_control_dashboard_path
    end

    test "mission control dashboard path resolves callable when route exists" do
      Feedmon.configure do |config|
        config.mission_control_dashboard_path = -> { Feedmon::Engine.routes.url_helpers.root_path }
      end

      assert_nothing_raised do
        Rails.application.routes.recognize_path(Feedmon::Engine.routes.url_helpers.root_path, method: :get)
      end

      assert_equal Feedmon::Engine.routes.url_helpers.root_path, Feedmon.mission_control_dashboard_path
    end

    test "mission control dashboard path allows external URLs" do
      Feedmon.configure do |config|
        config.mission_control_dashboard_path = "https://status.example.com/mission-control"
      end

      assert_equal "https://status.example.com/mission-control", Feedmon.mission_control_dashboard_path
    end

    test "scraper registry returns configured adapters" do
      Feedmon.configure do |config|
        config.scrapers.register(:custom_readability, Feedmon::Scrapers::Readability)
      end

      adapter = Feedmon.config.scrapers.adapter_for("custom_readability")
      assert_equal Feedmon::Scrapers::Readability, adapter
    end

    test "retention settings default to destroy strategy" do
      assert_equal :destroy, Feedmon.config.retention.strategy

      Feedmon.configure do |config|
        config.retention.strategy = :soft_delete
      end

      assert_equal :soft_delete, Feedmon.config.retention.strategy
    end

    test "fetching settings expose defaults and allow overrides" do
      settings = Feedmon.config.fetching
      assert_equal 5, settings.min_interval_minutes
      assert_equal 24 * 60, settings.max_interval_minutes
      assert_equal 1.25, settings.increase_factor
      assert_equal 0.75, settings.decrease_factor
      assert_equal 1.5, settings.failure_increase_factor
      assert_equal 0.1, settings.jitter_percent

      Feedmon.configure do |config|
        config.fetching.min_interval_minutes = 15
        config.fetching.max_interval_minutes = 720
        config.fetching.increase_factor = 1.4
        config.fetching.decrease_factor = 0.6
        config.fetching.failure_increase_factor = 2.2
        config.fetching.jitter_percent = 0.05
      end

      updated = Feedmon.config.fetching
      assert_equal 15, updated.min_interval_minutes
      assert_equal 720, updated.max_interval_minutes
      assert_in_delta 1.4, updated.increase_factor
      assert_in_delta 0.6, updated.decrease_factor
      assert_in_delta 2.2, updated.failure_increase_factor
      assert_in_delta 0.05, updated.jitter_percent
    end
  end
end
