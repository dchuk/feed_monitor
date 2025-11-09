# frozen_string_literal: true

module SourceMonitor
  class ScrapeLogsController < ApplicationController
    def show
      @log = ScrapeLog.includes(:item, :source).find(params[:id])
    end
  end
end
