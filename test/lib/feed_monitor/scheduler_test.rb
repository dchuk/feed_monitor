require "test_helper"
require "securerandom"

module FeedMonitor
  class SchedulerTest < ActiveSupport::TestCase
    include ActiveJob::TestHelper

    setup do
      FeedMonitor::Item.delete_all
      FeedMonitor::Source.delete_all
      clear_enqueued_jobs
    end

    teardown do
      clear_enqueued_jobs
    end

    test "enqueues fetch jobs for sources due for fetch" do
      now = Time.current
      due_one = create_source(next_fetch_at: now - 5.minutes)
      due_two = create_source(next_fetch_at: nil)
      _future = create_source(next_fetch_at: now + 30.minutes)

      assert_enqueued_jobs 0

      travel_to(now) do
        assert_difference -> { enqueued_jobs.size }, 2 do
          FeedMonitor::Scheduler.run(limit: nil)
        end
      end

      job_args = enqueued_jobs.map { |job| job[:args] }
      assert_equal 2, job_args.size

      normalized = job_args.map do |args|
        { id: args.first, force: args.last["force"] }
      end

      assert_includes normalized, { id: due_one.id, force: false }
      assert_includes normalized, { id: due_two.id, force: false }
    end

    test "uses skip locked when selecting due sources" do
      now = Time.current
      create_source(next_fetch_at: now - 1.minute)

      sql = capture_sql do
        FeedMonitor::Scheduler.run(limit: 1, now: now)
      end

      assert sql.any? { |statement| statement =~ /FOR UPDATE SKIP LOCKED/i }, "expected due source query to use SKIP LOCKED"
    end

    test "returns number of sources enqueued" do
      now = Time.current
      create_source(next_fetch_at: now - 1.minute)

      travel_to(now) do
        assert_equal 1, FeedMonitor::Scheduler.run(limit: nil)
      end
    end

    test "skips sources already marked as queued" do
      now = Time.current
      source = create_source(next_fetch_at: now - 5.minutes, fetch_status: "queued")
      source.update_columns(updated_at: now)

      travel_to(now) do
        assert_no_difference -> { enqueued_jobs.size } do
          FeedMonitor::Scheduler.run(limit: nil)
        end
      end
    end

    test "re-enqueues sources stuck in queued state beyond timeout" do
      now = Time.current
      source = create_source(next_fetch_at: now - 1.hour, fetch_status: "queued")
      stale_time = now - (FeedMonitor::Scheduler::STALE_QUEUE_TIMEOUT + 5.minutes)
      source.update_columns(updated_at: stale_time)

      travel_to(now) do
        assert_difference -> { enqueued_jobs.size }, 1 do
          FeedMonitor::Scheduler.run(limit: nil)
        end
      end
    end

    test "includes sources with failed status in eligible fetch statuses" do
      now = Time.current
      failed_source = create_source(next_fetch_at: now - 5.minutes, fetch_status: "failed")
      idle_source = create_source(next_fetch_at: now - 5.minutes, fetch_status: "idle")

      travel_to(now) do
        assert_difference -> { enqueued_jobs.size }, 2 do
          FeedMonitor::Scheduler.run(limit: nil)
        end
      end

      job_args = enqueued_jobs.map { |job| job[:args].first }
      assert_includes job_args, failed_source.id
      assert_includes job_args, idle_source.id
    end

    test "fetch status predicate includes eligible and stale queued sources" do
      now = Time.current
      idle = create_source(fetch_status: "idle")
      failed = create_source(fetch_status: "failed")
      queued_recent = create_source(fetch_status: "queued")
      queued_stale = create_source(fetch_status: "queued")

      queued_recent.update_columns(updated_at: now)
      queued_stale.update_columns(updated_at: now - (FeedMonitor::Scheduler::STALE_QUEUE_TIMEOUT + 2.minutes))

      scheduler = FeedMonitor::Scheduler.new(limit: 10, now: now)
      predicate = scheduler.send(:fetch_status_predicate)

      ids = FeedMonitor::Source.where(predicate).pluck(:id)

      assert_includes ids, idle.id
      assert_includes ids, failed.id
      assert_includes ids, queued_stale.id
      refute_includes ids, queued_recent.id
    end

    test "instruments scheduler runs and updates metrics" do
      FeedMonitor::Metrics.reset!
      now = Time.current
      create_source(next_fetch_at: now - 1.minute)

      events = []
      subscription = ActiveSupport::Notifications.subscribe("feed_monitor.scheduler.run") do |*args|
        events << args.last
      end

      travel_to(now) do
        FeedMonitor::Scheduler.run(limit: nil)
      end

      assert_equal 1, events.size
      payload = events.first
      assert_equal 1, payload[:enqueued_count]
      assert payload[:duration_ms].is_a?(Numeric)

      snapshot = FeedMonitor::Metrics.snapshot
      assert_equal 1, snapshot[:counters]["scheduler_runs_total"]
      assert_equal 1, snapshot[:counters]["scheduler_sources_enqueued_total"]
      assert_equal 1, snapshot[:gauges]["scheduler_last_enqueued_count"]
      assert snapshot[:gauges]["scheduler_last_duration_ms"] >= 0
      assert snapshot[:gauges]["scheduler_last_run_at_epoch"].positive?
    ensure
      ActiveSupport::Notifications.unsubscribe(subscription) if subscription
      FeedMonitor::Metrics.reset!
    end

  private

    def create_source(overrides = {})
      defaults = {
        name: "Source #{SecureRandom.hex(4)}",
        feed_url: "https://example.com/feed-#{SecureRandom.hex(8)}.xml",
        website_url: "https://example.com",
        fetch_interval_minutes: 60,
        active: true
      }

      create_source!(defaults.merge(overrides))
    end

    def capture_sql
      statements = []
      callback = lambda do |_, _, _, _, payload|
        statements << payload[:sql] if payload[:sql]
      end

      ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
        yield
      end

      statements
    end
  end
end
