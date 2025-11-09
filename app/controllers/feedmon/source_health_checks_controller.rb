# frozen_string_literal: true

module Feedmon
  class SourceHealthChecksController < ApplicationController
    include Feedmon::SourceTurboResponses

    before_action :set_source

    def create
      Feedmon::SourceHealthCheckJob.perform_later(@source.id)
      render_fetch_enqueue_response(
        "Health check enqueued",
        health_status_override: processing_badge
      )
    rescue StandardError => error
      handle_fetch_failure(error, prefix: "Health check")
    end

    private

    def set_source
      @source = Source.find(params[:source_id])
    end

    def processing_badge
      {
        label: "Processing",
        classes: "bg-blue-100 text-blue-700",
        show_spinner: true,
        status: "processing"
      }
    end
  end
end
