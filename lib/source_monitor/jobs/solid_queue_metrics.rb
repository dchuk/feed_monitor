# frozen_string_literal: true

module SourceMonitor
  module Jobs
    class SolidQueueMetrics
      QueueSummary = Struct.new(
        :queue_name,
        :ready_count,
        :scheduled_count,
        :failed_count,
        :recurring_count,
        :paused,
        :last_enqueued_at,
        :last_started_at,
        :last_finished_at,
        :available,
        keyword_init: true
      ) do
        def total_count
          ready_count + scheduled_count + failed_count
        end
      end

      DEFAULT_QUEUE_NAME = "default"

      def self.call(queue_names:)
        new(queue_names).call
      end

      def initialize(queue_names)
        @queue_names = Array(queue_names).map(&:to_s)
      end

      def call
        metrics = initialize_metrics

        return metrics unless solid_queue_supported?

        populate_counts(metrics)
        populate_timestamps(metrics)
        populate_pause_state(metrics)

        metrics
      rescue ActiveRecord::StatementInvalid, ActiveRecord::ConnectionNotEstablished
        @solid_queue_supported = false
        initialize_metrics
      end

      private

      attr_reader :queue_names

      def initialize_metrics
        queue_names.index_with do |queue_name|
          QueueSummary.new(
            queue_name: queue_name,
            ready_count: 0,
            scheduled_count: 0,
            failed_count: 0,
            recurring_count: 0,
            paused: false,
            last_enqueued_at: nil,
            last_started_at: nil,
            last_finished_at: nil,
            available: solid_queue_supported?
          )
        end
      end

      def solid_queue_supported?
        return @solid_queue_supported if defined?(@solid_queue_supported)

        @solid_queue_supported =
          defined?(::SolidQueue::Job) &&
          defined?(::SolidQueue::ReadyExecution) &&
          defined?(::SolidQueue::ScheduledExecution) &&
          table_exists?(::SolidQueue::Job) &&
          table_exists?(::SolidQueue::ReadyExecution) &&
          table_exists?(::SolidQueue::ScheduledExecution)
      end

      def populate_counts(metrics)
        merge_counts(metrics, ready_counts, :ready_count)
        merge_counts(metrics, scheduled_counts, :scheduled_count)
        merge_counts(metrics, failed_counts, :failed_count)
        merge_counts(metrics, recurring_counts, :recurring_count)
      end

      def populate_timestamps(metrics)
        merge_counts(metrics, last_enqueued_times, :last_enqueued_at)
        merge_counts(metrics, last_started_times, :last_started_at)
        merge_counts(metrics, last_finished_times, :last_finished_at)
      end

      def populate_pause_state(metrics)
        return unless table_exists?(::SolidQueue::Pause)

        paused_queue_names.each do |queue_name|
          summary = metrics[queue_name]
          next unless summary

          summary.paused = true
        end
      end

      def merge_counts(metrics, collection, attribute)
        collection.each do |queue_name, value|
          summary = metrics[queue_name.to_s]
          next unless summary

          summary.public_send("#{attribute}=", value)
        end
      end

      def ready_counts
        return {} unless table_exists?(::SolidQueue::ReadyExecution)

        ::SolidQueue::ReadyExecution.
          where(queue_name: queue_names).
          group(:queue_name).
          count
      end

      def scheduled_counts
        return {} unless table_exists?(::SolidQueue::ScheduledExecution)

        ::SolidQueue::ScheduledExecution.
          where(queue_name: queue_names).
          group(:queue_name).
          count
      end

      def failed_counts
        return {} unless defined?(::SolidQueue::FailedExecution) && table_exists?(::SolidQueue::FailedExecution)

        ::SolidQueue::FailedExecution.
          joins(:job).
          where(::SolidQueue::Job.arel_table[:queue_name].in(queue_names)).
          group(::SolidQueue::Job.arel_table[:queue_name]).
          count
      end

      def recurring_counts
        return {} unless defined?(::SolidQueue::RecurringTask) && table_exists?(::SolidQueue::RecurringTask)

        ::SolidQueue::RecurringTask.
          group(:queue_name).
          count.
          transform_keys { |queue_name| normalize_queue_name(queue_name) }.
          select { |queue_name, _| queue_names.include?(queue_name) }
      end

      def last_enqueued_times
        ::SolidQueue::Job.
          where(queue_name: queue_names).
          group(:queue_name).
          maximum(:created_at)
      end

      def last_started_times
        return {} unless defined?(::SolidQueue::ClaimedExecution) && table_exists?(::SolidQueue::ClaimedExecution)

        ::SolidQueue::ClaimedExecution.
          joins(:job).
          where(::SolidQueue::Job.arel_table[:queue_name].in(queue_names)).
          group(::SolidQueue::Job.arel_table[:queue_name]).
          maximum(arel_table_for(::SolidQueue::ClaimedExecution)[:created_at])
      end

      def last_finished_times
        ::SolidQueue::Job.
          where(queue_name: queue_names).
          where.not(finished_at: nil).
          group(:queue_name).
          maximum(:finished_at)
      end

      def paused_queue_names
        ::SolidQueue::Pause.
          where(queue_name: queue_names).
          pluck(:queue_name)
      end

      def table_exists?(model)
        model.respond_to?(:table_exists?) && model.table_exists?
      rescue ActiveRecord::StatementInvalid, ActiveRecord::NoDatabaseError
        false
      end

      def normalize_queue_name(name)
        (name.presence || DEFAULT_QUEUE_NAME).to_s
      end

      def arel_table_for(model)
        model.arel_table
      end
    end
  end
end
