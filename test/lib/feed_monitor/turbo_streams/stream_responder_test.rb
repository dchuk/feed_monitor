# frozen_string_literal: true

require "test_helper"

module FeedMonitor
  module TurboStreams
    class StreamResponderTest < ActiveSupport::TestCase
      setup do
        @source = create_source!
      end

      test "records replace operations for resource details" do
        responder = FeedMonitor::TurboStreams::StreamResponder.new
        responder.replace_details(@source, partial: "feed_monitor/sources/details_wrapper", locals: { source: @source })

        operation = responder.operations.first

        assert_equal :replace, operation.action
        assert_equal ActionView::RecordIdentifier.dom_id(@source, :details), operation.target
        assert_equal "feed_monitor/sources/details_wrapper", operation.partial
        assert_equal({ source: @source }, operation.locals)
      end

      test "records toast notification append" do
        responder = FeedMonitor::TurboStreams::StreamResponder.new
        responder.toast(message: "Queued", level: :info, delay_ms: 1234)

        operation = responder.operations.first

        assert_equal :append, operation.action
        assert_equal "feed_monitor_notifications", operation.target
        assert_equal "feed_monitor/shared/toast", operation.partial
        assert_equal({ message: "Queued", level: :info, title: nil, delay_ms: 1234 }, operation.locals)
      end

      test "renders operations into turbo stream tags" do
        responder = FeedMonitor::TurboStreams::StreamResponder.new
        responder.append("custom_target", partial: "feed_monitor/shared/toast", locals: { message: "Hello", level: :info, title: nil, delay_ms: 1000 })

        controller = FeedMonitor::SourcesController.new
        controller.request = ActionDispatch::TestRequest.create
        controller.response = ActionDispatch::TestResponse.new

        rendered = responder.render(controller.view_context)

        assert_equal 1, rendered.size
        assert_includes rendered.first, "<turbo-stream"
        assert_includes rendered.first, "Hello"
      end
    end
  end
end
