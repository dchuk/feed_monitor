# frozen_string_literal: true

module FeedMonitor
  class DashboardController < ApplicationController
    def index
      @stats = build_stats
      @recent_activity = build_recent_activity
      @quick_actions = build_quick_actions
      @job_adapter = FeedMonitor::Jobs::Visibility.adapter_name
      @job_metrics = build_job_metrics
      @mission_control_enabled = FeedMonitor.mission_control_enabled?
      @mission_control_dashboard_path = FeedMonitor.mission_control_dashboard_path
    end

    private

    def build_stats
      {
        total_sources: Source.count,
        active_sources: Source.active.count,
        failed_sources: Source.failed.count,
        total_items: Item.count,
        fetches_today: FetchLog.where("started_at >= ?", Time.zone.today.beginning_of_day).count
      }
    end

    def build_recent_activity
      fetch_events = FetchLog.order(started_at: :desc).limit(5).map do |log|
        {
          time: log.started_at,
          label: "Fetch ##{log.id}",
          status: log.success? ? :success : :failure,
          description: "#{log.items_created} created / #{log.items_updated} updated",
          type: :fetch
        }
      end

      scrape_events = ScrapeLog.order(started_at: :desc).limit(5).map do |log|
        {
          time: log.started_at,
          label: "Scrape ##{log.id}",
          status: log.success? ? :success : :failure,
          description: log.scraper_adapter.presence || "Scraper",
          type: :scrape
        }
      end

      (fetch_events + scrape_events).
        sort_by { |event| event[:time] || Time.zone.at(0) }.
        reverse.
        first(8)
    end

    def build_quick_actions
      [
        {
          label: "Add Source",
          description: "Create a new feed source",
          path: feed_monitor.new_source_path
        },
        {
          label: "View Sources",
          description: "Manage existing sources",
          path: feed_monitor.sources_path
        },
        {
          label: "Check Health",
          description: "Verify engine status",
          path: feed_monitor.health_path
        }
      ]
    end

    def build_job_metrics
      queue_names = {
        fetch: FeedMonitor.queue_name(:fetch),
        scrape: FeedMonitor.queue_name(:scrape)
      }

      queue_names.each_value do |queue_name|
        FeedMonitor::Jobs::Visibility.state_for(queue_name)
      end

      snapshot = FeedMonitor::Jobs::Visibility.state_snapshot

      queue_names.map do |role, queue_name|
        state = snapshot[queue_name.to_s] || {}
        {
          role: role,
          queue_name: queue_name,
          depth: state[:depth].to_i,
          last_enqueued_at: state[:last_enqueued_at],
          last_started_at: state[:last_started_at],
          last_finished_at: state[:last_finished_at]
        }
      end
    end
  end
end
