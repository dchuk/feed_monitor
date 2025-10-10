# frozen_string_literal: true

module FeedMonitor
  class DashboardController < ApplicationController
    def index
      @stats = FeedMonitor::Dashboard::Queries.stats
      @recent_activity = FeedMonitor::Dashboard::Queries.recent_activity
      @quick_actions = FeedMonitor::Dashboard::Queries.quick_actions
      @job_adapter = FeedMonitor::Jobs::Visibility.adapter_name
      @job_metrics = FeedMonitor::Dashboard::Queries.job_metrics
      @mission_control_enabled = FeedMonitor.mission_control_enabled?
      @mission_control_dashboard_path = FeedMonitor.mission_control_dashboard_path
    end
  end
end
