# frozen_string_literal: true

require "test_helper"

module Feedmon
  class ApplicationControllerTest < ActionDispatch::IntegrationTest
    test "invokes host configured authentication callbacks" do
      calls = []

      Feedmon.configure do |config|
        config.authentication.authenticate_with do |controller|
          calls << [ :authenticate, controller.class.name ]
        end

        config.authentication.authorize_with do |controller|
          calls << [ :authorize, controller.class.name ]
        end
      end

      get "/feedmon/dashboard"

      assert_response :success
      assert_includes calls, [ :authenticate, "Feedmon::DashboardController" ]
      assert_includes calls, [ :authorize, "Feedmon::DashboardController" ]
      assert_equal [ :authenticate, "Feedmon::DashboardController" ], calls.first
    end

    test "skips authentication when host has not configured it" do
      get "/feedmon/dashboard"

      assert_response :success
    end

    test "uses exception strategy for CSRF protection" do
      assert_equal ActionController::RequestForgeryProtection::ProtectionMethods::Exception,
        Feedmon::ApplicationController.forgery_protection_strategy
    end

    test "toast_delay_for returns appropriate delays based on level" do
      controller = Feedmon::ApplicationController.new

      assert_equal 5000, controller.send(:toast_delay_for, :info)
      assert_equal 5000, controller.send(:toast_delay_for, :success)
      assert_equal 5000, controller.send(:toast_delay_for, :warning)
      assert_equal 6000, controller.send(:toast_delay_for, :error)
    end

    test "toast_delay_for returns default for unknown level" do
      controller = Feedmon::ApplicationController.new

      assert_equal 5000, controller.send(:toast_delay_for, :unknown)
    end
  end
end
