# frozen_string_literal: true

module SourceMonitor
  module Jobs
    module FetchFailureCallbacks
      extend ActiveSupport::Concern

      included do
        after_create :notify_source_monitor_of_failure
      end

      private

      def notify_source_monitor_of_failure
        SourceMonitor::Jobs::FetchFailureSubscriber.handle_failed_execution(self)
      end
    end

    class FetchFailureSubscriber
      PROCESS_FAILURE_CLASSES = %w[
        SolidQueue::Processes::ProcessExitError
        SolidQueue::Processes::ProcessPrunedError
      ].freeze

      class << self
        def setup!
          register_on_load_hook!
          attach_callbacks! if solid_queue_loaded?
        end

        def handle_failed_execution(failed_execution)
          job = failed_execution.job
          return unless job
          return unless job.queue_name == SourceMonitor.queue_name(:fetch)

          error = failed_execution.error || {}
          return unless PROCESS_FAILURE_CLASSES.include?(error["exception_class"])

          source_id = extract_source_id(job)
          return unless source_id

          source = SourceMonitor::Source.find_by(id: source_id)
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

          SourceMonitor::Realtime.broadcast_source(source)
        rescue StandardError => exception
          log_failure(source_id, exception)
        end

        def attach_callbacks!
          failed_execution_class = load_failed_execution_class
          return unless failed_execution_class
          return if failed_execution_class < FetchFailureCallbacks

          failed_execution_class.include(FetchFailureCallbacks)
        end

        private

        def solid_queue_loaded?
          !!load_failed_execution_class
        end

        def register_on_load_hook!
          return if @hook_registered

          ActiveSupport.on_load(:solid_queue) do
            SourceMonitor::Jobs::FetchFailureSubscriber.attach_callbacks!
          end

          @hook_registered = true
        end

        def load_failed_execution_class
          ::SolidQueue::FailedExecution
        rescue NameError
          begin
            require "solid_queue/failed_execution"
          rescue LoadError
            return nil
          end

          ::SolidQueue::FailedExecution
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
            "[SourceMonitor::Jobs::FetchFailureSubscriber] Failed to handle process failure for source #{source_id.inspect}: #{exception.class}: #{exception.message}"
          )
        end
      end
    end
  end
end
