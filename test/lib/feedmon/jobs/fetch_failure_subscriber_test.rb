# frozen_string_literal: true

require "test_helper"

module Feedmon
  module Jobs
    class FetchFailureSubscriberTest < ActiveSupport::TestCase
      setup do
        Feedmon::Jobs::FetchFailureSubscriber.setup!
        cleanup_solid_queue_tables
      end

      teardown do
        cleanup_solid_queue_tables
      end

      test "marks source as failed when a fetch job fails due to process exit" do
        source = create_source!(fetch_status: "fetching", last_fetch_started_at: 20.minutes.ago, failure_count: 0)
        job = enqueue_fetch_job_for(source)
        source.update_columns(fetch_status: "fetching")

        assert_includes SolidQueue::FailedExecution.ancestors, Feedmon::Jobs::FetchFailureCallbacks

        SolidQueue::FailedExecution.create!(
          job:,
          error: {
            "exception_class" => "SolidQueue::Processes::ProcessExitError",
            "message" => "Received unhandled signal 11.",
            "backtrace" => nil
          }
        )

        source.reload
        assert_equal "failed", source.fetch_status
        assert_match(/ProcessExitError/, source.last_error)
        assert_equal 1, source.failure_count
      end

      test "ignores non process-exit failures" do
        source = create_source!(fetch_status: "fetching", last_fetch_started_at: 10.minutes.ago, failure_count: 0)
        job = enqueue_fetch_job_for(source)
        source.update_columns(fetch_status: "fetching")

        SolidQueue::FailedExecution.create!(
          job:,
          error: {
            "exception_class" => "RuntimeError",
            "message" => "Boom",
            "backtrace" => nil
          }
        )

        source.reload
        assert_equal "fetching", source.fetch_status
        assert_nil source.last_error
        assert_equal 0, source.failure_count
      end

      test "setup registers callbacks for later Solid Queue load" do
        subscriber = Feedmon::Jobs::FetchFailureSubscriber
        subscriber.instance_variable_set(:@hook_registered, false)

        captured = nil

        ActiveSupport.stub(:on_load, ->(name, &block) { captured = block if name == :solid_queue }) do
          subscriber.stub(:solid_queue_loaded?, false) do
            subscriber.setup!
          end
        end

        refute_nil captured

        attach_calls = 0
        subscriber.stub(:attach_callbacks!, -> { attach_calls += 1 }) do
          captured.call
        end

        assert_equal 1, attach_calls
      ensure
        subscriber.instance_variable_set(:@hook_registered, false)
      end

      private

      def enqueue_fetch_job_for(source)
        with_queue_adapter(:solid_queue) do
          Feedmon::Fetching::FetchRunner.enqueue(source.id)
        end

        SolidQueue::Job.order(:id).last
      end

      def cleanup_solid_queue_tables
        if defined?(SolidQueue::FailedExecution)
          SolidQueue::FailedExecution.delete_all
        end

        if defined?(SolidQueue::ClaimedExecution)
          SolidQueue::ClaimedExecution.delete_all
        end

        if defined?(SolidQueue::ReadyExecution)
          SolidQueue::ReadyExecution.delete_all
        end

        if defined?(SolidQueue::ScheduledExecution)
          SolidQueue::ScheduledExecution.delete_all
        end

        if defined?(SolidQueue::Job)
          SolidQueue::Job.delete_all
        end
      end
    end
  end
end
