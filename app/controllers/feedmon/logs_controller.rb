# frozen_string_literal: true

module Feedmon
  class LogsController < ApplicationController
    def index
      @query_result = Feedmon::Logs::Query.new(params: params).call
      @filter_set = @query_result.filter_set
      @filter_params = @filter_set.to_params.symbolize_keys
      @rows = Feedmon::Logs::TablePresenter.new(
        entries: @query_result.entries,
        url_helpers: Feedmon::Engine.routes.url_helpers
      ).rows
    end
  end
end
