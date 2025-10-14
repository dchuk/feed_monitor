# frozen_string_literal: true

module FeedMonitor
  module Sources
    # Presenter for building Turbo Stream responses for source-related actions
    # Consolidates duplicated response building logic from the controller
    class TurboStreamPresenter
      include ActionView::RecordIdentifier

      attr_reader :source, :responder

      def initialize(source:, responder:)
        @source = source
        @responder = responder
      end

      # Builds the complete Turbo Stream response for source deletion
      # Includes: row removal, heatmap update, empty state (if needed), and redirect (if provided)
      def render_deletion(metrics:, query:, search_params:, redirect_location: nil)
        responder.remove_row(source)
        responder.remove("feed_monitor_sources_empty_state")

        render_heatmap_update(metrics:, search_params:)
        render_empty_state_if_needed(query:)
        responder.redirect(redirect_location, action: "replace") if redirect_location.present?

        self
      end

      private

      def render_heatmap_update(metrics:, search_params:)
        responder.replace(
          "feed_monitor_sources_heatmap",
          partial: "feed_monitor/sources/fetch_interval_heatmap",
          locals: {
            fetch_interval_distribution: metrics.fetch_interval_distribution,
            selected_bucket: metrics.selected_fetch_interval_bucket,
            search_params:
          }
        )
      end

      def render_empty_state_if_needed(query:)
        return if query.result.exists?

        responder.append(
          "feed_monitor_sources_table_body",
          partial: "feed_monitor/sources/empty_state_row"
        )
      end
    end
  end
end
