# frozen_string_literal: true

require "active_support/core_ext/numeric/time"
require "feed_monitor/fetching/stalled_fetch_reconciler"

module FeedMonitor
  class Scheduler
    DEFAULT_BATCH_SIZE = 100
    STALE_QUEUE_TIMEOUT = 10.minutes
    ELIGIBLE_FETCH_STATUSES = %w[idle failed].freeze

    def self.run(limit: DEFAULT_BATCH_SIZE, now: Time.current)
      new(limit:, now:).run
    end

    def initialize(limit:, now:)
      @limit = limit
      @now = now
    end

    def run
      payload = { limit: limit }
      recovery = FeedMonitor::Fetching::StalledFetchReconciler.call(now:, stale_after: STALE_QUEUE_TIMEOUT)
      payload[:stalled_recoveries] = recovery.recovered_source_ids.size
      payload[:stalled_jobs_removed] = recovery.jobs_removed.size

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
        .where(fetch_status_predicate)
        .order(Arel.sql("next_fetch_at ASC NULLS FIRST"))
    end

    def due_for_fetch_predicate
      table = FeedMonitor::Source.arel_table
      table[:next_fetch_at].eq(nil).or(table[:next_fetch_at].lteq(now))
    end

    def fetch_status_predicate
      table = FeedMonitor::Source.arel_table

      eligible = table[:fetch_status].in(ELIGIBLE_FETCH_STATUSES)
      stale_cutoff = now - STALE_QUEUE_TIMEOUT
      stale_queued = table[:fetch_status].eq("queued").and(table[:updated_at].lteq(stale_cutoff))
      stale_fetching = table[:fetch_status].eq("fetching").and(table[:last_fetch_started_at].lteq(stale_cutoff))

      eligible.or(stale_queued).or(stale_fetching)
    end
  end
end
