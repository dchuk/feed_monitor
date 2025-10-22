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

      broadcasted_sources = []
      toasts = []

      FeedMonitor::Realtime.stub(:broadcast_source, ->(record) { broadcasted_sources << record }) do
        FeedMonitor::Realtime.stub(:broadcast_toast, ->(**payload) { toasts << payload }) do
          FeedMonitor::SourceHealthCheckJob.perform_later(source.id)
          perform_enqueued_jobs
        end
      end

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

      assert_equal [ source ], broadcasted_sources
      refute_empty toasts
      assert_equal :error, toasts.last[:level]
      assert_match(/Health check/i, toasts.last[:message])
    end

    test "broadcasts UI updates and toast when health check succeeds" do
      source = create_source!(feed_url: "https://example.com/feed.xml")

      stub_request(:get, source.feed_url).to_return(
        status: 200,
        body: "",
        headers: { "Content-Type" => "application/rss+xml" }
      )

      broadcasted_sources = []
      toasts = []

      FeedMonitor::Realtime.stub(:broadcast_source, ->(record) { broadcasted_sources << record }) do
        FeedMonitor::Realtime.stub(:broadcast_toast, ->(**payload) { toasts << payload }) do
          FeedMonitor::SourceHealthCheckJob.perform_later(source.id)
          perform_enqueued_jobs
        end
      end

      assert_equal [ source ], broadcasted_sources
      refute_empty toasts
      toast = toasts.last
      assert_equal :success, toast[:level]
      assert_match(/Health check/i, toast[:message])
    end

    test "records unexpected errors and broadcasts failure toast" do
      source = create_source!(feed_url: "https://example.com/feed.xml")

      broadcasts = []
      toasts = []

      failing_service = Class.new do
        def initialize(*); end

        def call
          raise StandardError, "boom"
        end
      end

      FeedMonitor::Health::SourceHealthCheck.stub(:new, ->(**) { failing_service.new }) do
        FeedMonitor::Realtime.stub(:broadcast_source, ->(record) { broadcasts << record }) do
          FeedMonitor::Realtime.stub(:broadcast_toast, ->(**payload) { toasts << payload }) do
            FeedMonitor::SourceHealthCheckJob.perform_now(source.id)
          end
        end
      end

      log = FeedMonitor::HealthCheckLog.order(:created_at).last
      assert_equal source, log.source
      assert_equal false, log.success?
      assert_equal "boom", log.error_message

      assert_equal [ source ], broadcasts
      assert_equal :error, toasts.last[:level]
      assert_match(/failed/i, toasts.last[:message])
    end

    test "swallows logging errors when failure recording fails" do
      source = create_source!(feed_url: "https://example.com/feed.xml")

      failing_service = Class.new do
        def initialize(*); end

        def call
          raise StandardError, "boom"
        end
      end

      failing_service = Class.new do
        def initialize(*); end

        def call
          raise StandardError, "boom"
        end
      end

      FeedMonitor::Health::SourceHealthCheck.stub(:new, ->(**) { failing_service.new }) do
        FeedMonitor::HealthCheckLog.stub(:create!, ->(**) { raise StandardError, "log failure" }) do
          assert_nothing_raised do
            FeedMonitor::SourceHealthCheckJob.perform_now(source.id)
          end
        end
      end
    end
  end
end
