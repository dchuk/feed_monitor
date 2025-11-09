module Feedmon
  class HealthController < ApplicationController
    def show
      render json: {
        status: "ok",
        metrics: Feedmon::Metrics.snapshot
      }
    end
  end
end
