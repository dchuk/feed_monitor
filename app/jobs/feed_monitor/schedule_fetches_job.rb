# frozen_string_literal: true

module FeedMonitor
  class ScheduleFetchesJob < ApplicationJob
    feed_monitor_queue :fetch

    def perform(options = nil)
      limit = extract_limit(options)
      FeedMonitor::Scheduler.run(limit:)
    end

    private

    def extract_limit(options)
      options_hash =
        case options
        when nil then {}
        when Hash then options
        else {}
        end

      if options_hash.respond_to?(:symbolize_keys)
        options_hash = options_hash.symbolize_keys
      end

      options_hash[:limit] || FeedMonitor::Scheduler::DEFAULT_BATCH_SIZE
    end
  end
end
