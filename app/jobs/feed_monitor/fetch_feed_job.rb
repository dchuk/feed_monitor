# frozen_string_literal: true

module FeedMonitor
  class FetchFeedJob < ApplicationJob
    FETCH_CONCURRENCY_RETRY_WAIT = 30.seconds

    feed_monitor_queue :fetch

    discard_on ActiveJob::DeserializationError

    def perform(source_id)
      source = FeedMonitor::Source.find_by(id: source_id)
      return unless source

      FeedMonitor::Fetching::FetchRunner.new(source: source).run
    rescue FeedMonitor::Fetching::FetchRunner::ConcurrencyError
      retry_job wait: FETCH_CONCURRENCY_RETRY_WAIT
    end
  end
end
