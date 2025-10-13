# frozen_string_literal: true

module FeedMonitor
  module Dashboard
    class QuickActionsPresenter
      def initialize(actions, url_helpers:)
        @actions = actions
        @url_helpers = url_helpers
      end

      def to_a
        actions.map do |action|
          {
            label: action.label,
            description: action.description,
            path: url_helpers.public_send(action.route_name)
          }
        end
      end

      private

      attr_reader :actions, :url_helpers
    end
  end
end
