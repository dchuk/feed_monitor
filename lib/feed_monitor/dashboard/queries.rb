# frozen_string_literal: true

require "feed_monitor/dashboard/upcoming_fetch_schedule"

module FeedMonitor
  module Dashboard
    module Queries
      module_function

      def stats
        {
          total_sources: Source.count,
          active_sources: Source.active.count,
          failed_sources: Source.failed.count,
          total_items: Item.count,
          fetches_today: FetchLog.where("started_at >= ?", Time.zone.today.beginning_of_day).count
        }
      end

      def recent_activity(limit: 8)
        helpers = FeedMonitor::Engine.routes.url_helpers

        fetch_events = FetchLog.order(started_at: :desc).limit(limit).map do |log|
          {
            time: log.started_at,
            label: "Fetch ##{log.id}",
            status: log.success? ? :success : :failure,
            description: "#{log.items_created} created / #{log.items_updated} updated",
            type: :fetch,
            path: helpers.fetch_log_path(log)
          }
        end

        scrape_events = ScrapeLog.order(started_at: :desc).limit(limit).map do |log|
          {
            time: log.started_at,
            label: "Scrape ##{log.id}",
            status: log.success? ? :success : :failure,
            description: log.scraper_adapter.presence || "Scraper",
            type: :scrape,
            path: helpers.scrape_log_path(log)
          }
        end

        item_events = Item.includes(:source).order(created_at: :desc).limit(limit).map do |item|
          {
            time: item.created_at,
            label: item.title.presence || "New Item",
            status: :success,
            description: item.source&.name || item.url || "New feed item",
            type: :item,
            path: helpers.item_path(item)
          }
        end

        (fetch_events + scrape_events + item_events).
          sort_by { |event| event[:time] || Time.zone.at(0) }.
          reverse.
          first(limit)
      end

      def quick_actions
        [
          {
            label: "Add Source",
            description: "Create a new feed source",
            path: FeedMonitor::Engine.routes.url_helpers.new_source_path
          },
          {
            label: "View Sources",
            description: "Manage existing sources",
            path: FeedMonitor::Engine.routes.url_helpers.sources_path
          },
          {
            label: "Check Health",
            description: "Verify engine status",
            path: FeedMonitor::Engine.routes.url_helpers.health_path
          }
        ]
      end

      def job_metrics(queue_names: queue_name_map.values)
        summaries = FeedMonitor::Jobs::SolidQueueMetrics.call(queue_names:)

        queue_name_map.map do |role, queue_name|
          summary = summaries[queue_name.to_s] ||
            FeedMonitor::Jobs::SolidQueueMetrics::QueueSummary.new(
              queue_name: queue_name.to_s,
              ready_count: 0,
              scheduled_count: 0,
              failed_count: 0,
              recurring_count: 0,
              paused: false,
              last_enqueued_at: nil,
              last_started_at: nil,
              last_finished_at: nil,
              available: false
            )

          {
            role: role,
            queue_name: queue_name,
            summary: summary
          }
        end
      end

      def upcoming_fetch_schedule
        FeedMonitor::Dashboard::UpcomingFetchSchedule.new(scope: Source.active)
      end

      def queue_name_map
        {
          fetch: FeedMonitor.queue_name(:fetch),
          scrape: FeedMonitor.queue_name(:scrape)
        }
      end
      private_class_method :queue_name_map
    end
  end
end
