# frozen_string_literal: true

require "test_helper"

module FeedMonitor
  module Dashboard
    class QuickActionsPresenterTest < ActiveSupport::TestCase
      test "decorates quick actions with resolved paths" do
        actions = [
          FeedMonitor::Dashboard::QuickAction.new(
            label: "Health",
            description: "Check engine status",
            route_name: :health_path
          )
        ]

        presenter = FeedMonitor::Dashboard::QuickActionsPresenter.new(
          actions,
          url_helpers: FeedMonitor::Engine.routes.url_helpers
        )

        result = presenter.to_a.first
        assert_equal "Health", result[:label]
        assert_equal FeedMonitor::Engine.routes.url_helpers.health_path, result[:path]
      end
    end
  end
end
