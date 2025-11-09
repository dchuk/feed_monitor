# frozen_string_literal: true

module Feedmon
  class DashboardController < ApplicationController
    def index
      queries = Feedmon::Dashboard::Queries.new
      url_helpers = Feedmon::Engine.routes.url_helpers

      @stats = queries.stats
      @recent_activity = Feedmon::Dashboard::RecentActivityPresenter.new(
        queries.recent_activity,
        url_helpers:
      ).to_a
      @quick_actions = Feedmon::Dashboard::QuickActionsPresenter.new(
        queries.quick_actions,
        url_helpers:
      ).to_a
      @job_adapter = Feedmon::Jobs::Visibility.adapter_name
      @job_metrics = queries.job_metrics
      fetch_schedule = queries.upcoming_fetch_schedule
      @fetch_schedule_groups = fetch_schedule.groups
      @fetch_schedule_reference_time = fetch_schedule.reference_time
      @mission_control_enabled = Feedmon.mission_control_enabled?
      @mission_control_dashboard_path = Feedmon.mission_control_dashboard_path
    end
  end
end
