# frozen_string_literal: true

require "test_helper"

module SourceMonitor
  class SourceHealthChecksControllerTest < ActionDispatch::IntegrationTest
    include SourceMonitor::Engine.routes.url_helpers

    setup do
      @source = create_source!(name: "Health Check Source")
    end

    test "enqueues health check and renders turbo stream response" do
      SourceMonitor::SourceHealthCheckJob.stub(:perform_later, ->(id) { assert_equal @source.id, id }) do
        post source_health_check_path(@source), as: :turbo_stream
      end

      assert_response :success
      assert_equal "text/vnd.turbo-stream.html", @response.media_type
      assert_includes @response.body, "Health check enqueued"
      assert_includes @response.body, "Processing"
    end

    test "handles enqueue errors with turbo stream toast" do
      SourceMonitor::SourceHealthCheckJob.stub(:perform_later, ->(*) { raise StandardError, "boom" }) do
        post source_health_check_path(@source), as: :turbo_stream
      end

      assert_response :unprocessable_entity
      assert_includes @response.body, "Health check could not be enqueued"
    end
  end
end
