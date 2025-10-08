# frozen_string_literal: true

require "active_support/notifications"

module FeedMonitor
  module Metrics
    module_function

    def increment(name, value = 1)
      counters[name.to_s] += value
    end

    def gauge(name, value)
      gauges[name.to_s] = value
    end

    def counter(name)
      counters[name.to_s]
    end

    def gauge_value(name)
      gauges[name.to_s]
    end

    def snapshot
      { counters: counters.dup, gauges: gauges.dup }
    end

    def reset!
      @counters = Hash.new(0)
      @gauges = {}
    end

    def setup_subscribers!
      return if defined?(@subscribed) && @subscribed

      ActiveSupport::Notifications.subscribe("feed_monitor.fetch.start") do |_name, _start, _finish, _id, payload|
        increment(:fetch_started_total)
        gauge(:last_fetch_source_id, payload[:source_id]) if payload.key?(:source_id)
      end

      ActiveSupport::Notifications.subscribe("feed_monitor.fetch.finish") do |_name, start, finish, _id, payload|
        increment(:fetch_finished_total)
        success = payload.fetch(:success, true)
        if success
          increment(:fetch_success_total)
        else
          increment(:fetch_failure_total)
        end

        duration_ms = payload[:duration_ms] || ((finish - start) * 1000.0).round(2)
        gauge(:last_fetch_duration_ms, duration_ms)
      end

      @subscribed = true
    end

    def counters
      @counters ||= Hash.new(0)
    end

    def gauges
      @gauges ||= {}
    end
  end
end
