# frozen_string_literal: true

class FeedmonMetricsController < ApplicationController
  before_action :authenticate_feedmon!

  def show
    render json: Feedmon::Metrics.snapshot
  end

  private

  def authenticate_feedmon!
    return if respond_to?(:authenticate_admin!) && authenticate_admin!

    # This example keeps things simple by gating access behind basic HTTP auth.
    # Replace with your host application's auth hooks before shipping to prod.
    authenticate_or_request_with_http_basic("Feedmon Metrics") do |user, pass|
      ActiveSupport::SecurityUtils.secure_compare(user, ENV.fetch("FEEDMON_METRICS_USER", "monitor")) &&
        ActiveSupport::SecurityUtils.secure_compare(pass, ENV.fetch("FEEDMON_METRICS_PASS", "monitor"))
    end
  end
end
