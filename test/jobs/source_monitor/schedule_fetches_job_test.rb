# frozen_string_literal: true

require "test_helper"
require "minitest/mock"

module SourceMonitor
  class ScheduleFetchesJobTest < ActiveJob::TestCase
    test "invokes scheduler with the default limit when no options passed" do
      captured_limit = nil

      SourceMonitor::Scheduler.stub(:run, ->(limit:) { captured_limit = limit }) do
        SourceMonitor::ScheduleFetchesJob.perform_now
      end

      assert_equal SourceMonitor::Scheduler::DEFAULT_BATCH_SIZE, captured_limit
    end

    test "passes through an explicit limit when provided" do
      captured_limit = nil

      SourceMonitor::Scheduler.stub(:run, ->(limit:) { captured_limit = limit }) do
        SourceMonitor::ScheduleFetchesJob.perform_now({ "limit" => 25 })
      end

      assert_equal 25, captured_limit
    end
  end
end
