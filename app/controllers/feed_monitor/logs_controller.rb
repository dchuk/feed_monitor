# frozen_string_literal: true

module FeedMonitor
  class LogsController < ApplicationController
    def index
      @query_result = FeedMonitor::Logs::Query.new(params: params).call
      @filter_set = @query_result.filter_set
      @filter_params = @filter_set.to_params.symbolize_keys
      @rows = FeedMonitor::Logs::TablePresenter.new(
        entries: @query_result.entries,
        url_helpers: FeedMonitor::Engine.routes.url_helpers
      ).rows
    end
  end
end
