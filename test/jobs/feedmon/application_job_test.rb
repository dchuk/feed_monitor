# frozen_string_literal: true

require "test_helper"

module Feedmon
  class ApplicationJobTest < ActiveSupport::TestCase
    test "inherits from host ApplicationJob when available" do
      assert Feedmon::ApplicationJob < ::ApplicationJob
    end

    test "provides helper for selecting feed monitor queues" do
      Feedmon.reset_configuration!
      Feedmon.configure do |config|
        config.fetch_queue_name = "custom_feed_queue"
      end

      feed_job_class = Class.new(Feedmon::ApplicationJob) do
        feedmon_queue :fetch
      end

      feed_job_class.define_singleton_method(:name) { "Feedmon::TestFetchJob" }

      assert_equal "custom_feed_queue", feed_job_class.queue_name
    ensure
      Feedmon.reset_configuration!
    end
  end
end
