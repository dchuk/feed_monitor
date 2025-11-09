# frozen_string_literal: true

require "test_helper"

module Feedmon
  class SourceHealthResetsControllerTest < ActionDispatch::IntegrationTest
    include Feedmon::Engine.routes.url_helpers

    setup do
      @source = create_source!(
        name: "Auto Paused Source",
        health_status: "auto_paused",
        auto_paused_until: 30.minutes.from_now
      )
    end

    test "resets health state and broadcasts updates" do
      reset_calls = []
      broadcasts = []

      Feedmon::Health::SourceHealthReset.stub(:call, ->(source:) { reset_calls << source }) do
        Feedmon::Realtime.stub(:broadcast_source, ->(source) { broadcasts << source }) do
          post source_health_reset_path(@source), as: :turbo_stream
        end
      end

      assert_response :success
      assert_equal [ @source ], reset_calls
      assert_equal [ @source ], broadcasts
      assert_includes @response.body, "Health state reset"
    end

    test "handles reset errors with failure toast" do
      Feedmon::Health::SourceHealthReset.stub(:call, ->(*) { raise StandardError, "nope" }) do
        post source_health_reset_path(@source), as: :turbo_stream
      end

      assert_response :unprocessable_entity
      assert_includes @response.body, "Health reset could not be enqueued"
    end
  end
end
