# frozen_string_literal: true

class SourceMonitorMetricsController < ApplicationController
  before_action :authenticate_source_monitor!

  def show
    render json: SourceMonitor::Metrics.snapshot
  end

  private

  def authenticate_source_monitor!
    return if respond_to?(:authenticate_admin!) && authenticate_admin!

    # This example keeps things simple by gating access behind basic HTTP auth.
    # Replace with your host application's auth hooks before shipping to prod.
    authenticate_or_request_with_http_basic("SourceMonitor Metrics") do |user, pass|
      ActiveSupport::SecurityUtils.secure_compare(user, ENV.fetch("SOURCE_MONITOR_METRICS_USER", "monitor")) &&
        ActiveSupport::SecurityUtils.secure_compare(pass, ENV.fetch("SOURCE_MONITOR_METRICS_PASS", "monitor"))
    end
  end
end
