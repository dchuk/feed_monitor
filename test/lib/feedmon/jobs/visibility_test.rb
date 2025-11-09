# frozen_string_literal: true

require "test_helper"

module Feedmon
  module Jobs
    class VisibilityTest < ActiveSupport::TestCase
      class DummyJob < Feedmon::ApplicationJob
        feedmon_queue :fetch

        def perform(*)
          # no-op
        end
      end

      setup do
        Feedmon.reset_configuration!
        Feedmon.configure do |config|
          config.fetch_queue_name = "feedmon_fetch_test"
        end
        DummyJob.queue_as Feedmon.queue_name(:fetch)
        Feedmon::Metrics.reset!
        Feedmon::Jobs::Visibility.reset!
        Feedmon::Jobs::Visibility.setup!
      end

      teardown do
        Feedmon.reset_configuration!
        Feedmon::Jobs::Visibility.reset!
      end

      test "tracks queue depth and timestamps for feed monitor jobs" do
        queue_name = Feedmon.queue_name(:fetch)
        job = DummyJob.new

        assert_equal "Feedmon::Jobs::VisibilityTest::DummyJob", job.class.name
        assert_equal "feedmon_fetch_test", job.queue_name

        probe_events = []
        probe_subscriber = ActiveSupport::Notifications.subscribe("enqueue.active_job") { |*_args| probe_events << true }
        ActiveSupport::Notifications.instrument("enqueue.active_job", job: job) { }
        ActiveSupport::Notifications.unsubscribe(probe_subscriber)
        assert_equal 1, probe_events.size

        Feedmon::Jobs::Visibility.reset!
        Feedmon::Jobs::Visibility.setup!

        assert Feedmon::Jobs::Visibility.trackable_job?(job)
        assert_equal 0, Feedmon::Jobs::Visibility.queue_depth(queue_name)

        ActiveSupport::Notifications.instrument("enqueue.active_job", job: job) { }

        assert_equal 1, Feedmon::Jobs::Visibility.queue_depth(queue_name)
        assert_kind_of ActiveSupport::TimeWithZone, Feedmon::Jobs::Visibility.last_enqueued_at(queue_name)

        ActiveSupport::Notifications.instrument("perform_start.active_job", job: job) { }

        assert_equal 0, Feedmon::Jobs::Visibility.queue_depth(queue_name)
        assert_kind_of ActiveSupport::TimeWithZone, Feedmon::Jobs::Visibility.last_started_at(queue_name)

        ActiveSupport::Notifications.instrument("perform.active_job", job: job) { }

        assert_kind_of ActiveSupport::TimeWithZone, Feedmon::Jobs::Visibility.last_finished_at(queue_name)
      end
    end
  end
end
