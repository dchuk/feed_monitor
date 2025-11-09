# frozen_string_literal: true

module SourceMonitor
  class LogsController < ApplicationController
    def index
      @query_result = SourceMonitor::Logs::Query.new(params: params).call
      @filter_set = @query_result.filter_set
      @filter_params = @filter_set.to_params.symbolize_keys
      @rows = SourceMonitor::Logs::TablePresenter.new(
        entries: @query_result.entries,
        url_helpers: SourceMonitor::Engine.routes.url_helpers
      ).rows
    end
  end
end
