# frozen_string_literal: true

module FeedMonitor
  class Scheduler
    DEFAULT_BATCH_SIZE = 100

    def self.run(limit: DEFAULT_BATCH_SIZE, now: Time.current)
      new(limit:, now:).run
    end

    def initialize(limit:, now:)
      @limit = limit
      @now = now
    end

    def run
      payload = { limit: limit }

      ActiveSupport::Notifications.instrument("feed_monitor.scheduler.run", payload) do
        start_monotonic = FeedMonitor::Instrumentation.monotonic_time
        source_ids = lock_due_source_ids
        payload[:enqueued_count] = source_ids.size

        source_ids.each do |source_id|
          FeedMonitor::Fetching::FetchRunner.enqueue(source_id)
        end

        payload[:duration_ms] = ((FeedMonitor::Instrumentation.monotonic_time - start_monotonic) * 1000.0).round(2)

        source_ids.size
      end
    end

    private

    attr_reader :limit, :now

    def lock_due_source_ids
      ids = []

      FeedMonitor::Source.transaction do
        rows = due_sources_relation
        rows = rows.limit(limit) if limit
        ids = rows.lock("FOR UPDATE SKIP LOCKED").pluck(:id)
      end

      ids
    end

    def due_sources_relation
      FeedMonitor::Source
        .active
        .where(due_for_fetch_predicate)
        .order(Arel.sql("next_fetch_at ASC NULLS FIRST"))
    end

    def due_for_fetch_predicate
      table = FeedMonitor::Source.arel_table
      table[:next_fetch_at].eq(nil).or(table[:next_fetch_at].lteq(now))
    end
  end
end
