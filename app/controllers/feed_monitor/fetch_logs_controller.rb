# frozen_string_literal: true

module FeedMonitor
  class FetchLogsController < ApplicationController
    def show
      @log = FetchLog.includes(:source).find(params[:id])
    end
  end
end
