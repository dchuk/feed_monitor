# frozen_string_literal: true

require "test_helper"
require "securerandom"

module SourceMonitor
  module Jobs
    class SolidQueueMetricsTest < ActiveSupport::TestCase
      setup do
        purge_solid_queue_tables
      end

      teardown do
        purge_solid_queue_tables
      end

      test "aggregates counts and timestamps per queue" do
        fetch_queue = SourceMonitor.queue_name(:fetch)
        scrape_queue = SourceMonitor.queue_name(:scrape)
        base_time = Time.zone.local(2025, 10, 10, 9, 0, 0)

        travel_to(base_time) do
          create_job(queue_name: fetch_queue)
        end

        travel_to(base_time + 5.minutes) do
          create_job(queue_name: fetch_queue, scheduled_at: 10.minutes.from_now)
        end

        travel_to(base_time + 10.minutes) do
          job = create_job(queue_name: fetch_queue)
          job.ready_execution&.destroy!
          SolidQueue::FailedExecution.create!(job:, error: "RuntimeError: boom")
        end

        claimed_timestamp = nil
        travel_to(base_time + 15.minutes) do
          job = create_job(queue_name: fetch_queue)
          job.ready_execution&.destroy!
          process = SolidQueue::Process.create!(
            kind: "worker",
            pid: 123,
            name: "worker-123",
            last_heartbeat_at: Time.current,
            metadata: {}
          )
          SolidQueue::ClaimedExecution.create!(job:, process:)
          claimed_timestamp = SolidQueue::ClaimedExecution.maximum(:created_at)
        end

        enqueued_timestamp = finished_timestamp = nil
        travel_to(base_time + 20.minutes) do
          job = create_job(queue_name: fetch_queue, finished_at: Time.current)
          job.ready_execution&.destroy!
          enqueued_timestamp = job.created_at
          finished_timestamp = job.finished_at
        end

        travel_to(base_time + 25.minutes) do
          SolidQueue::RecurringTask.create!(
            key: "source_monitor_test_#{SecureRandom.hex(4)}",
            schedule: "every minute",
            class_name: "SourceMonitor::ScheduleFetchesJob",
            queue_name: fetch_queue
          )
          SolidQueue::Pause.create!(queue_name: fetch_queue)
        end

        metrics = SourceMonitor::Jobs::SolidQueueMetrics.call(queue_names: [ fetch_queue, scrape_queue ])

        fetch_metrics = metrics.fetch(fetch_queue.to_s)

        assert fetch_metrics.available
        assert_equal 1, fetch_metrics.ready_count
        assert_equal 1, fetch_metrics.scheduled_count
        assert_equal 1, fetch_metrics.failed_count
        assert_equal 1, fetch_metrics.recurring_count
        assert fetch_metrics.paused
        assert_equal enqueued_timestamp.to_i, fetch_metrics.last_enqueued_at.to_i
        assert_equal claimed_timestamp.to_i, fetch_metrics.last_started_at.to_i
        assert_equal finished_timestamp.to_i, fetch_metrics.last_finished_at.to_i

        scrape_metrics = metrics.fetch(scrape_queue.to_s)
        assert scrape_metrics.available
        assert_equal 0, scrape_metrics.total_count
        assert_equal 0, scrape_metrics.recurring_count
        assert_not scrape_metrics.paused
      end

      private

      def create_job(queue_name:, scheduled_at: nil, finished_at: nil)
        SolidQueue::Job.create!(
          queue_name: queue_name,
          class_name: "SourceMonitor::FetchFeedJob",
          arguments: [],
          scheduled_at: scheduled_at,
          finished_at: finished_at
        )
      end

      def purge_solid_queue_tables
        [
          ::SolidQueue::RecurringExecution,
          ::SolidQueue::RecurringTask,
          ::SolidQueue::ClaimedExecution,
          ::SolidQueue::FailedExecution,
          ::SolidQueue::BlockedExecution,
          ::SolidQueue::ScheduledExecution,
          ::SolidQueue::ReadyExecution,
          ::SolidQueue::Process,
          ::SolidQueue::Pause,
          ::SolidQueue::Job
        ].each do |model|
          next unless model.respond_to?(:delete_all) && table_exists?(model)

          model.delete_all
        end
      end

      def table_exists?(model)
        model.table_exists?
      rescue ActiveRecord::StatementInvalid, ActiveRecord::NoDatabaseError
        false
      end
    end
  end
end
