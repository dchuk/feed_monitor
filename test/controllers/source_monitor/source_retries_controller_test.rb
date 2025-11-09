# frozen_string_literal: true

require "test_helper"

module SourceMonitor
  class SourceRetriesControllerTest < ActionDispatch::IntegrationTest
    include ActiveJob::TestHelper
    include ActionView::RecordIdentifier

    teardown do
      clear_enqueued_jobs
    end

    test "forces a fetch and renders turbo stream" do
      source = create_source!(fetch_status: "failed")

      expected_args = [ source.id, { force: true } ]
      assert_enqueued_jobs 1, only: SourceMonitor::FetchFeedJob do
        assert_enqueued_with(job: SourceMonitor::FetchFeedJob, args: expected_args) do
          post source_monitor.source_retry_path(source), as: :turbo_stream
        end
      end

      assert_response :success
      assert_includes response.body, %(<turbo-stream action="replace" target="#{dom_id(source, :row)}">)

      source.reload
      assert_equal "queued", source.fetch_status
    end

    test "returns an error turbo stream when retry enqueue fails" do
      source = create_source!(fetch_status: "failed")

      SourceMonitor::Fetching::FetchRunner.stub(:enqueue, ->(*) { raise StandardError, "retry boom" }) do
        assert_enqueued_jobs 0, only: SourceMonitor::FetchFeedJob do
          post source_monitor.source_retry_path(source), as: :turbo_stream
        end
      end

      assert_response :unprocessable_entity
      assert_includes response.body, "Fetch could not be enqueued: retry boom"
    end
  end
end
