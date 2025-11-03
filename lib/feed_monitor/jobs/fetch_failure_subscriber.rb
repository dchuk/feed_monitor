# frozen_string_literal: true

module FeedMonitor
  module Jobs
    module FetchFailureCallbacks
      extend ActiveSupport::Concern

      included do
        after_create :notify_feed_monitor_of_failure
      end

      private

      def notify_feed_monitor_of_failure
        FeedMonitor::Jobs::FetchFailureSubscriber.handle_failed_execution(self)
      end
    end

    class FetchFailureSubscriber
      PROCESS_FAILURE_CLASSES = %w[
        SolidQueue::Processes::ProcessExitError
        SolidQueue::Processes::ProcessPrunedError
      ].freeze

      class << self
        def setup!
          return unless defined?(::SolidQueue::FailedExecution)
          return if configured?

          ActiveSupport.on_load(:solid_queue) do
            FeedMonitor::Jobs::FetchFailureSubscriber.attach_callbacks!
          end

          attach_callbacks! if solid_queue_loaded?
          @configured = true
        end

        def handle_failed_execution(failed_execution)
          job = failed_execution.job
          return unless job
          return unless job.queue_name == FeedMonitor.queue_name(:fetch)

          error = failed_execution.error || {}
          return unless PROCESS_FAILURE_CLASSES.include?(error["exception_class"])

          source_id = extract_source_id(job)
          return unless source_id

          source = FeedMonitor::Source.find_by(id: source_id)
          return unless source

          now = Time.current

          source.with_lock do
            source.reload
            update_attributes = {
              fetch_status: "failed",
              last_error: formatted_error_message(error),
              last_error_at: now,
              failure_count: source.failure_count.to_i + 1,
              next_fetch_at: now,
              backoff_until: nil
            }
            source.update!(update_attributes)
          end

          FeedMonitor::Realtime.broadcast_source(source)
        rescue StandardError => exception
          log_failure(source_id, exception)
        end

        def attach_callbacks!
          return unless solid_queue_loaded?
          return if ::SolidQueue::FailedExecution < FetchFailureCallbacks

          ::SolidQueue::FailedExecution.include(FetchFailureCallbacks)
        end

        private

        def solid_queue_loaded?
          defined?(::SolidQueue::FailedExecution)
        end

        def configured?
          !!@configured
        end

        def extract_source_id(job)
          arguments = job.arguments
          return unless arguments.is_a?(Hash)

          args_array = arguments["arguments"]
          return unless args_array.is_a?(Array)

          source_arg = args_array.first
          Integer(source_arg)
        rescue ArgumentError, TypeError
          nil
        end

        def formatted_error_message(error)
          message = error["message"] || "Fetch job terminated unexpectedly"
          "#{error['exception_class']}: #{message}"
        end

        def log_failure(source_id, exception)
          return unless defined?(Rails) && Rails.respond_to?(:logger) && Rails.logger

          Rails.logger.error(
            "[FeedMonitor::Jobs::FetchFailureSubscriber] Failed to handle process failure for source #{source_id.inspect}: #{exception.class}: #{exception.message}"
          )
        end
      end
    end
  end
end
