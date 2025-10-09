# frozen_string_literal: true

require "test_helper"

module FeedMonitor
  module Jobs
    class VisibilityTest < ActiveSupport::TestCase
      class DummyJob < FeedMonitor::ApplicationJob
        feed_monitor_queue :fetch

        def perform(*)
          # no-op
        end
      end

      setup do
        FeedMonitor.reset_configuration!
        FeedMonitor.configure do |config|
          config.fetch_queue_name = "feed_monitor_fetch_test"
        end
        DummyJob.queue_as FeedMonitor.queue_name(:fetch)
        FeedMonitor::Metrics.reset!
        FeedMonitor::Jobs::Visibility.reset!
        FeedMonitor::Jobs::Visibility.setup!
      end

      teardown do
        FeedMonitor.reset_configuration!
        FeedMonitor::Jobs::Visibility.reset!
      end

      test "tracks queue depth and timestamps for feed monitor jobs" do
        queue_name = FeedMonitor.queue_name(:fetch)
        job = DummyJob.new

        assert_equal "FeedMonitor::Jobs::VisibilityTest::DummyJob", job.class.name
        assert_equal "feed_monitor_fetch_test", job.queue_name

        probe_events = []
        probe_subscriber = ActiveSupport::Notifications.subscribe("enqueue.active_job") { |*_args| probe_events << true }
        ActiveSupport::Notifications.instrument("enqueue.active_job", job: job) {}
        ActiveSupport::Notifications.unsubscribe(probe_subscriber)
        assert_equal 1, probe_events.size

        FeedMonitor::Jobs::Visibility.reset!
        FeedMonitor::Jobs::Visibility.setup!

        assert FeedMonitor::Jobs::Visibility.trackable_job?(job)
        assert_equal 0, FeedMonitor::Jobs::Visibility.queue_depth(queue_name)

        ActiveSupport::Notifications.instrument("enqueue.active_job", job: job) {}

        assert_equal 1, FeedMonitor::Jobs::Visibility.queue_depth(queue_name)
        assert_kind_of ActiveSupport::TimeWithZone, FeedMonitor::Jobs::Visibility.last_enqueued_at(queue_name)

        ActiveSupport::Notifications.instrument("perform_start.active_job", job: job) {}

        assert_equal 0, FeedMonitor::Jobs::Visibility.queue_depth(queue_name)
        assert_kind_of ActiveSupport::TimeWithZone, FeedMonitor::Jobs::Visibility.last_started_at(queue_name)

        ActiveSupport::Notifications.instrument("perform.active_job", job: job) {}

        assert_kind_of ActiveSupport::TimeWithZone, FeedMonitor::Jobs::Visibility.last_finished_at(queue_name)
      end
    end
  end
end
