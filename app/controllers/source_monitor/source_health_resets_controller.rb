# frozen_string_literal: true

module SourceMonitor
  class SourceHealthResetsController < ApplicationController
    include SourceMonitor::SourceTurboResponses

    before_action :set_source

    def create
      SourceMonitor::Health::SourceHealthReset.call(source: @source)
      SourceMonitor::Realtime.broadcast_source(@source)

      render_fetch_enqueue_response(
        "Health state reset",
        toast_level: :success
      )
    rescue StandardError => error
      handle_fetch_failure(error, prefix: "Health reset")
    end

    private

    def set_source
      @source = Source.find(params[:source_id])
    end
  end
end
