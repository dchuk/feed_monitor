# frozen_string_literal: true

module FeedMonitor
  class SourceHealthResetsController < ApplicationController
    include FeedMonitor::SourceTurboResponses

    before_action :set_source

    def create
      FeedMonitor::Health::SourceHealthReset.call(source: @source)
      FeedMonitor::Realtime.broadcast_source(@source)

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
