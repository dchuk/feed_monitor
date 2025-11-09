# frozen_string_literal: true

require "test_helper"

module Feedmon
  module Dashboard
    class RecentActivityPresenterTest < ActiveSupport::TestCase
      test "builds fetch event view model with path" do
        event = Feedmon::Dashboard::RecentActivity::Event.new(
          type: :fetch_log,
          id: 42,
          occurred_at: Time.current,
          success: true,
          items_created: 3,
          items_updated: 1
        )

        presenter = Feedmon::Dashboard::RecentActivityPresenter.new(
          [ event ],
          url_helpers: Feedmon::Engine.routes.url_helpers
        )

        result = presenter.to_a.first
        assert_equal "Fetch #42", result[:label]
        assert_equal :success, result[:status]
        assert_equal Feedmon::Engine.routes.url_helpers.fetch_log_path(42), result[:path]
      end

      test "builds item event view model with fallbacks" do
        event = Feedmon::Dashboard::RecentActivity::Event.new(
          type: :item,
          id: 7,
          occurred_at: Time.current,
          success: true,
          item_title: nil,
          item_url: "https://example.com/items/7",
          source_name: nil
        )

        presenter = Feedmon::Dashboard::RecentActivityPresenter.new(
          [ event ],
          url_helpers: Feedmon::Engine.routes.url_helpers
        )

        result = presenter.to_a.first
        assert_equal "New Item", result[:label]
        assert_equal "https://example.com/items/7", result[:description]
        assert_equal Feedmon::Engine.routes.url_helpers.item_path(7), result[:path]
      end
    end
  end
end
