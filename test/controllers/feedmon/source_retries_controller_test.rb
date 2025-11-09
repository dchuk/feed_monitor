# frozen_string_literal: true

require "test_helper"

module Feedmon
  class SourceRetriesControllerTest < ActionDispatch::IntegrationTest
    include ActiveJob::TestHelper
    include ActionView::RecordIdentifier

    teardown do
      clear_enqueued_jobs
    end

    test "forces a fetch and renders turbo stream" do
      source = create_source!(fetch_status: "failed")

      expected_args = [ source.id, { force: true } ]
      assert_enqueued_jobs 1, only: Feedmon::FetchFeedJob do
        assert_enqueued_with(job: Feedmon::FetchFeedJob, args: expected_args) do
          post feedmon.source_retry_path(source), as: :turbo_stream
        end
      end

      assert_response :success
      assert_includes response.body, %(<turbo-stream action="replace" target="#{dom_id(source, :row)}">)

      source.reload
      assert_equal "queued", source.fetch_status
    end

    test "returns an error turbo stream when retry enqueue fails" do
      source = create_source!(fetch_status: "failed")

      Feedmon::Fetching::FetchRunner.stub(:enqueue, ->(*) { raise StandardError, "retry boom" }) do
        assert_enqueued_jobs 0, only: Feedmon::FetchFeedJob do
          post feedmon.source_retry_path(source), as: :turbo_stream
        end
      end

      assert_response :unprocessable_entity
      assert_includes response.body, "Fetch could not be enqueued: retry boom"
    end
  end
end
