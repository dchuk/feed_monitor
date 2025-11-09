# frozen_string_literal: true

require "test_helper"

module Feedmon
  module Dashboard
    class QuickActionsPresenterTest < ActiveSupport::TestCase
      test "decorates quick actions with resolved paths" do
        actions = [
          Feedmon::Dashboard::QuickAction.new(
            label: "Health",
            description: "Check engine status",
            route_name: :health_path
          )
        ]

        presenter = Feedmon::Dashboard::QuickActionsPresenter.new(
          actions,
          url_helpers: Feedmon::Engine.routes.url_helpers
        )

        result = presenter.to_a.first
        assert_equal "Health", result[:label]
        assert_equal Feedmon::Engine.routes.url_helpers.health_path, result[:path]
      end
    end
  end
end
