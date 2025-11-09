# frozen_string_literal: true

require "test_helper"

module SourceMonitor
  module Jobs
    class VisibilityTest < ActiveSupport::TestCase
      class DummyJob < SourceMonitor::ApplicationJob
        source_monitor_queue :fetch

        def perform(*)
          # no-op
        end
      end

      setup do
        SourceMonitor.reset_configuration!
        SourceMonitor.configure do |config|
          config.fetch_queue_name = "source_monitor_fetch_test"
        end
        DummyJob.queue_as SourceMonitor.queue_name(:fetch)
        SourceMonitor::Metrics.reset!
        SourceMonitor::Jobs::Visibility.reset!
        SourceMonitor::Jobs::Visibility.setup!
      end

      teardown do
        SourceMonitor.reset_configuration!
        SourceMonitor::Jobs::Visibility.reset!
      end

      test "tracks queue depth and timestamps for SourceMonitor jobs" do
        queue_name = SourceMonitor.queue_name(:fetch)
        job = DummyJob.new

        assert_equal "SourceMonitor::Jobs::VisibilityTest::DummyJob", job.class.name
        assert_equal "source_monitor_fetch_test", job.queue_name

        probe_events = []
        probe_subscriber = ActiveSupport::Notifications.subscribe("enqueue.active_job") { |*_args| probe_events << true }
        ActiveSupport::Notifications.instrument("enqueue.active_job", job: job) { }
        ActiveSupport::Notifications.unsubscribe(probe_subscriber)
        assert_equal 1, probe_events.size

        SourceMonitor::Jobs::Visibility.reset!
        SourceMonitor::Jobs::Visibility.setup!

        assert SourceMonitor::Jobs::Visibility.trackable_job?(job)
        assert_equal 0, SourceMonitor::Jobs::Visibility.queue_depth(queue_name)

        ActiveSupport::Notifications.instrument("enqueue.active_job", job: job) { }

        assert_equal 1, SourceMonitor::Jobs::Visibility.queue_depth(queue_name)
        assert_kind_of ActiveSupport::TimeWithZone, SourceMonitor::Jobs::Visibility.last_enqueued_at(queue_name)

        ActiveSupport::Notifications.instrument("perform_start.active_job", job: job) { }

        assert_equal 0, SourceMonitor::Jobs::Visibility.queue_depth(queue_name)
        assert_kind_of ActiveSupport::TimeWithZone, SourceMonitor::Jobs::Visibility.last_started_at(queue_name)

        ActiveSupport::Notifications.instrument("perform.active_job", job: job) { }

        assert_kind_of ActiveSupport::TimeWithZone, SourceMonitor::Jobs::Visibility.last_finished_at(queue_name)
      end
    end
  end
end
