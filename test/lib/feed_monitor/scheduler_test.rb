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
