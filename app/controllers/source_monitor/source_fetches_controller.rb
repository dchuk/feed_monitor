# frozen_string_literal: true

module SourceMonitor
  class SourceFetchesController < ApplicationController
    include SourceMonitor::SourceTurboResponses

    before_action :set_source

    def create
      SourceMonitor::Fetching::FetchRunner.enqueue(@source.id)
      render_fetch_enqueue_response("Fetch has been enqueued and will run shortly.")
    rescue StandardError => error
      handle_fetch_failure(error)
    end

    private

    def set_source
      @source = Source.find(params[:source_id])
    end
  end
end
