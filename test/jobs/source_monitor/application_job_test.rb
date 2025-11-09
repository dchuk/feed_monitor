# frozen_string_literal: true

require "test_helper"

module SourceMonitor
  class ApplicationJobTest < ActiveSupport::TestCase
    test "inherits from host ApplicationJob when available" do
      assert SourceMonitor::ApplicationJob < ::ApplicationJob
    end

    test "provides helper for selecting SourceMonitor queues" do
      SourceMonitor.reset_configuration!
      SourceMonitor.configure do |config|
        config.fetch_queue_name = "custom_feed_queue"
      end

      feed_job_class = Class.new(SourceMonitor::ApplicationJob) do
        source_monitor_queue :fetch
      end

      feed_job_class.define_singleton_method(:name) { "SourceMonitor::TestFetchJob" }

      assert_equal "custom_feed_queue", feed_job_class.queue_name
    ensure
      SourceMonitor.reset_configuration!
    end
  end
end
