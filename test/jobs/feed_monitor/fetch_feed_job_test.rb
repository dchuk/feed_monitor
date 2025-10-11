require "test_helper"
require "minitest/mock"

module FeedMonitor
  class FetchFeedJobTest < ActiveJob::TestCase
    include ActiveJob::TestHelper

    setup do
      ActiveJob::Base.queue_adapter = :test
      clear_enqueued_jobs
      FeedMonitor::Source.delete_all
    end

    test "invokes the fetch runner for the source" do
      source = create_source
      runner = Minitest::Mock.new
      runner.expect(:run, :ok)

      FeedMonitor::Fetching::FetchRunner.stub(:new, ->(**_kwargs) { runner }) do
        FeedMonitor::FetchFeedJob.perform_now(source.id)
      end

      runner.verify
      assert_mock runner
    end

    test "retries when a concurrency error occurs" do
      source = create_source

      stub_runner = Class.new do
        def initialize(**); end

        def run
          raise FeedMonitor::Fetching::FetchRunner::ConcurrencyError, "locked"
        end
      end

      job = FeedMonitor::FetchFeedJob.new(source.id)

      FeedMonitor::Fetching::FetchRunner.stub(:new, ->(**_kwargs) { stub_runner.new }) do
        assert_enqueued_jobs 1 do
          job.perform_now
        end
      end

      enqueued = enqueued_jobs.last
      assert_equal FeedMonitor::FetchFeedJob, enqueued[:job]
      args = enqueued[:args]
      assert_equal source.id, args.first
      force_value = args[1]&.[]("force")
      assert_includes [nil, false], force_value
      assert enqueued[:at].present?, "expected retry to be scheduled in the future"
    end

    test "no-ops when the source is missing" do
      FeedMonitor::Fetching::FetchRunner.stub(:new, ->(**) { flunk("runner should not be initialized") }) do
        FeedMonitor::FetchFeedJob.perform_now(-1)
      end

      assert_enqueued_jobs 0
    end

    private

    def create_source
      create_source!(name: "Example Source")
    end
  end
end
