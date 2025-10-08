module FeedMonitor
  class HealthController < ApplicationController
    def show
      render json: {
        status: "ok",
        metrics: FeedMonitor::Metrics.snapshot
      }
    end
  end
end
