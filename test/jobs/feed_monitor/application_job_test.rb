# frozen_string_literal: true

require "test_helper"

module FeedMonitor
  class ApplicationJobTest < ActiveSupport::TestCase
    test "inherits from host ApplicationJob when available" do
      assert FeedMonitor::ApplicationJob < ::ApplicationJob
    end

    test "provides helper for selecting feed monitor queues" do
      FeedMonitor.reset_configuration!
      FeedMonitor.configure do |config|
        config.fetch_queue_name = "custom_feed_queue"
      end

      feed_job_class = Class.new(FeedMonitor::ApplicationJob) do
        feed_monitor_queue :fetch
      end

      feed_job_class.define_singleton_method(:name) { "FeedMonitor::TestFetchJob" }

      assert_equal "custom_feed_queue", feed_job_class.queue_name
    ensure
      FeedMonitor.reset_configuration!
    end
  end
end
