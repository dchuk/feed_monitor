# frozen_string_literal: true

require "active_support/notifications"

module FeedMonitor
  module Instrumentation
    FETCH_START_EVENT = "feed_monitor.fetch.start".freeze
    FETCH_FINISH_EVENT = "feed_monitor.fetch.finish".freeze

    module_function

    def fetch(payload = {})
      payload = payload.dup
      instrument(FETCH_START_EVENT, payload)

      started_at = monotonic_time
      result = yield if block_given?
      duration_ms = ((monotonic_time - started_at) * 1000.0).round(2)

      instrument(FETCH_FINISH_EVENT, payload.merge(duration_ms: duration_ms))
      result
    end

    def fetch_start(payload = {})
      instrument(FETCH_START_EVENT, payload)
    end

    def fetch_finish(payload = {})
      instrument(FETCH_FINISH_EVENT, payload)
    end

    def instrument(event_name, payload = {})
      ActiveSupport::Notifications.instrument(event_name, payload) do
        yield if block_given?
      end
    end

    def monotonic_time
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end
  end
end
