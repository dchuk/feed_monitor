# frozen_string_literal: true

require "active_support/notifications"
require "monitor"

module FeedMonitor
  module Jobs
    module Visibility
      module_function

      def setup!
        return if @subscribed || !FeedMonitor.config.job_metrics_enabled

        subscribe_enqueue
        subscribe_perform_start
        subscribe_perform

        @subscribed = true
      end

      def adapter_name
        ActiveJob::Base.queue_adapter_name
      end

      def queue_depth(queue_name)
        state_for(queue_name)[:depth]
      end

      def last_enqueued_at(queue_name)
        state_for(queue_name)[:last_enqueued_at]
      end

      def last_started_at(queue_name)
        state_for(queue_name)[:last_started_at]
      end

      def last_finished_at(queue_name)
        state_for(queue_name)[:last_finished_at]
      end

      def reset!
        synchronize do
          @queue_state = nil
        end
      end

      def state_snapshot
        synchronize do
          queue_state.transform_values(&:dup)
        end
      end

      def trackable_job?(job)
        job.class.name.start_with?("FeedMonitor::")
      rescue StandardError
        false
      end

      def queue_identifier(job)
        (job.queue_name || FeedMonitor.config.fetch_queue_name).to_s
      end

      def queue_state
        @queue_state ||= Hash.new do |hash, key|
          hash[key] = { depth: 0, last_enqueued_at: nil, last_started_at: nil, last_finished_at: nil }
        end
      end

      def state_for(name)
        synchronize do
          queue_state[name.to_s]
        end
      end

      def synchronize(&block)
        monitor.synchronize(&block)
      end

      def monitor
        @monitor ||= Monitor.new
      end

      def subscribe_enqueue
        ActiveSupport::Notifications.subscribe("enqueue.active_job") do |_event, _start, _finish, _id, payload|
          job = payload[:job]
          next unless trackable_job?(job)

          queue_name = queue_identifier(job)

          synchronize do
            state = queue_state[queue_name]
            state[:depth] += 1
            state[:last_enqueued_at] = Time.current
            FeedMonitor::Metrics.gauge("jobs_queue_depth_#{queue_name}", state[:depth])
            FeedMonitor::Metrics.gauge("jobs_last_enqueued_at_#{queue_name}", state[:last_enqueued_at])
          end
        end
      end

      def subscribe_perform_start
        ActiveSupport::Notifications.subscribe("perform_start.active_job") do |_event, _start, _finish, _id, payload|
          job = payload[:job]
          next unless trackable_job?(job)

          queue_name = queue_identifier(job)

          synchronize do
            state = queue_state[queue_name]
            state[:depth] = [ state[:depth] - 1, 0 ].max
            state[:last_started_at] = Time.current
            FeedMonitor::Metrics.gauge("jobs_queue_depth_#{queue_name}", state[:depth])
            FeedMonitor::Metrics.gauge("jobs_last_started_at_#{queue_name}", state[:last_started_at])
          end
        end
      end

      def subscribe_perform
        ActiveSupport::Notifications.subscribe("perform.active_job") do |_event, _start, _finish, _id, payload|
          job = payload[:job]
          next unless trackable_job?(job)

          queue_name = queue_identifier(job)

          synchronize do
            state = queue_state[queue_name]
            state[:last_finished_at] = Time.current
            FeedMonitor::Metrics.gauge("jobs_last_finished_at_#{queue_name}", state[:last_finished_at])
          end
        end
      end
    end
  end
end
