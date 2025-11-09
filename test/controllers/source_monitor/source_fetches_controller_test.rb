# frozen_string_literal: true

require "test_helper"

module SourceMonitor
  class SourceFetchesControllerTest < ActionDispatch::IntegrationTest
    include ActiveJob::TestHelper
    include ActionView::RecordIdentifier

    teardown do
      clear_enqueued_jobs
    end

    test "queues a fetch and renders turbo stream" do
      source = create_source!(fetch_status: "idle")

      assert_enqueued_jobs 1, only: SourceMonitor::FetchFeedJob do
        post source_monitor.source_fetch_path(source), as: :turbo_stream
      end

      assert_response :success
      assert_equal "text/vnd.turbo-stream.html", response.media_type
      assert_includes response.body, %(<turbo-stream action="replace" target="#{dom_id(source, :row)}">)

      source.reload
      assert_equal "queued", source.fetch_status
    end

    test "returns an error turbo stream when enqueue fails" do
      source = create_source!(fetch_status: "idle")

      SourceMonitor::Fetching::FetchRunner.stub(:enqueue, ->(*) { raise StandardError, "boom" }) do
        assert_enqueued_jobs 0, only: SourceMonitor::FetchFeedJob do
          post source_monitor.source_fetch_path(source), as: :turbo_stream
        end
      end

      assert_response :unprocessable_entity
      assert_equal "text/vnd.turbo-stream.html", response.media_type
      assert_includes response.body, "Fetch could not be enqueued: boom"
    end
  end
end
