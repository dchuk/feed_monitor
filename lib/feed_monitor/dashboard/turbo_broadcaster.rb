# frozen_string_literal: true

module FeedMonitor
  module Dashboard
    module TurboBroadcaster
      STREAM_NAME = "feed_monitor_dashboard"

      module_function

      def setup!
        return unless turbo_streams_available?

        register_callback(:after_fetch_completed, fetch_callback)
        register_callback(:after_item_created, item_callback)
      end

      def fetch_callback
        @fetch_callback ||= lambda { |_event| broadcast_dashboard_updates }
      end

      def item_callback
        @item_callback ||= lambda { |_event| broadcast_dashboard_updates }
      end

      def broadcast_dashboard_updates
        return unless turbo_streams_available?

        queries = FeedMonitor::Dashboard::Queries.new
        url_helpers = FeedMonitor::Engine.routes.url_helpers

        Turbo::StreamsChannel.broadcast_replace_to(
          STREAM_NAME,
          target: "feed_monitor_dashboard_stats",
          html: render_partial("feed_monitor/dashboard/stats", stats: queries.stats)
        )

        Turbo::StreamsChannel.broadcast_replace_to(
          STREAM_NAME,
          target: "feed_monitor_dashboard_recent_activity",
          html: render_partial(
            "feed_monitor/dashboard/recent_activity",
            recent_activity: FeedMonitor::Dashboard::RecentActivityPresenter.new(
              queries.recent_activity,
              url_helpers:
            ).to_a
          )
        )

        fetch_schedule = queries.upcoming_fetch_schedule
        Turbo::StreamsChannel.broadcast_replace_to(
          STREAM_NAME,
          target: "feed_monitor_dashboard_fetch_schedule",
          html: render_partial(
            "feed_monitor/dashboard/fetch_schedule",
            groups: fetch_schedule.groups,
            reference_time: fetch_schedule.reference_time
          )
        )
      rescue StandardError => error
        Rails.logger.error(
          "[FeedMonitor] Turbo stream broadcast failed: #{error.class}: #{error.message}"
        )
      end

      def turbo_streams_available?
        defined?(Turbo::StreamsChannel)
      end
      private_class_method :turbo_streams_available?

      def render_partial(partial, locals)
        FeedMonitor::DashboardController.render(
          partial:,
          locals:
        )
      end
      private_class_method :render_partial

      def register_callback(name, callback)
        callbacks = FeedMonitor.config.events.callbacks_for(name)
        return if callbacks.include?(callback)

        FeedMonitor.config.events.public_send(name, callback)
      end
      private_class_method :register_callback
    end
  end
end
