# frozen_string_literal: true

module Feedmon
  class FetchLogsController < ApplicationController
    def show
      @log = FetchLog.includes(:source).find(params[:id])
    end
  end
end
