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
          begin
            job.perform_now
          rescue StandardError
            # retry_on may raise internally; allow
          end
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

    test "schedules retry using retry policy when a transient fetch error bubbles up" do
      source = create_source(fetch_retry_attempt: 0)
      error = FeedMonitor::Fetching::TimeoutError.new("timeout")

      stub_runner = Class.new do
        def initialize(error:, **)
          @error = error
        end

        def run
          raise @error
        end
      end

      travel_to Time.zone.local(2025, 10, 12, 10, 0, 0) do
        FeedMonitor::Fetching::FetchRunner.stub(:new, ->(**_kwargs) { stub_runner.new(error:) }) do
          assert_enqueued_jobs 1 do
            begin
              FeedMonitor::FetchFeedJob.perform_now(source.id)
            rescue StandardError
              # retry_job does not raise, but guard if adapters behave differently
            end
          end
        end

        enqueued = enqueued_jobs.last
        assert_equal FeedMonitor::FetchFeedJob, enqueued[:job]
        assert_equal source.id, enqueued[:args].first
        wait_seconds = enqueued[:at] - Time.current.to_f
        assert_in_delta 2.minutes.to_i, wait_seconds, 1.0

        source.reload
        assert_equal 1, source.fetch_retry_attempt
        assert_equal "queued", source.fetch_status
        assert_in_delta 2.minutes.from_now, source.next_fetch_at, 1.second
        assert_in_delta 2.minutes.from_now, source.backoff_until, 1.second
      end
    end

    test "opens circuit and does not retry when policy exhausts attempts" do
      source = create_source(fetch_retry_attempt: 2)
      error = FeedMonitor::Fetching::TimeoutError.new("timeout")

      stub_runner = Class.new do
        def initialize(error:, **)
          @error = error
        end

        def run
          raise @error
        end
      end

      travel_to Time.zone.local(2025, 10, 12, 12, 0, 0) do
        FeedMonitor::Fetching::FetchRunner.stub(:new, ->(**_kwargs) { stub_runner.new(error:) }) do
          assert_enqueued_jobs 0 do
            assert_raises(FeedMonitor::Fetching::TimeoutError) do
              FeedMonitor::FetchFeedJob.perform_now(source.id)
            end
          end
        end

        source.reload
        assert_equal 0, source.fetch_retry_attempt
        assert_equal "failed", source.fetch_status
        assert source.fetch_circuit_until.present?
        assert source.backoff_until.present?
        assert source.next_fetch_at.present?
        assert source.fetch_circuit_until >= Time.current
        assert_equal source.fetch_circuit_until, source.next_fetch_at
      end
    end

    test "no-ops when the source is missing" do
      FeedMonitor::Fetching::FetchRunner.stub(:new, ->(**) { flunk("runner should not be initialized") }) do
        FeedMonitor::FetchFeedJob.perform_now(-1)
      end

      assert_enqueued_jobs 0
    end

    private

    def create_source(attributes = {})
      create_source!(
        { name: "Example Source" }.merge(attributes)
      )
    end
  end
end
