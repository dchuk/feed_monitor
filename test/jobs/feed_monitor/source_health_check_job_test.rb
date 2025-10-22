# frozen_string_literal: true

require "test_helper"

module FeedMonitor
  class SourceHealthCheckJobTest < ActiveJob::TestCase
    include ActiveJob::TestHelper

    setup do
      FeedMonitor::HealthCheckLog.delete_all if defined?(FeedMonitor::HealthCheckLog)
      FeedMonitor::Source.delete_all
      clear_enqueued_jobs
    end

    teardown do
      clear_enqueued_jobs
    end

    test "creates successful health check log" do
      source = create_source!(feed_url: "https://example.com/feed.xml")

      stub_request(:get, source.feed_url).to_return(status: 200, body: "", headers: { "Content-Type" => "application/rss+xml" })

      assert_enqueued_with(job: FeedMonitor::SourceHealthCheckJob, args: [ source.id ]) do
        FeedMonitor::SourceHealthCheckJob.perform_later(source.id)
      end

      perform_enqueued_jobs

      log = FeedMonitor::HealthCheckLog.order(:created_at).last
      assert_not_nil log, "expected a health check log to be created"
      assert_equal source, log.source
      assert log.success?, "expected the log to be marked as success"
      assert_equal 200, log.http_status

      entry = FeedMonitor::LogEntry.order(:created_at).last
      assert_equal log, entry.loggable
      assert entry.success?, "expected log entry to be successful"
      assert_equal "FeedMonitor::HealthCheckLog", entry.loggable_type
    end

    test "records failure details without raising" do
      source = create_source!(feed_url: "https://example.com/feed.xml")

      stub_request(:get, source.feed_url).to_timeout

      FeedMonitor::SourceHealthCheckJob.perform_later(source.id)
      perform_enqueued_jobs

      log = FeedMonitor::HealthCheckLog.order(:created_at).last
      assert_not_nil log, "expected failure log to be stored"
      refute log.success?
      assert_nil log.http_status
      assert_match(/expired|timeout/i, log.error_message.to_s)
      assert log.error_class.present?

      entry = FeedMonitor::LogEntry.order(:created_at).last
      assert_equal log, entry.loggable
      refute entry.success?
      assert_equal source, entry.source
    end
  end
end
