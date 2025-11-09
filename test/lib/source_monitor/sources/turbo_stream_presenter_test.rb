# frozen_string_literal: true

require "test_helper"
require "source_monitor/sources/turbo_stream_presenter"

module SourceMonitor
  module Sources
    class TurboStreamPresenterTest < ActiveSupport::TestCase
      def setup
        @source = SourceMonitor::Source.create!(
          name: "Test Source",
          feed_url: "https://example.com/feed.xml",
          fetch_interval_minutes: 60
        )
        @responder = SourceMonitor::TurboStreams::StreamResponder.new
        @presenter = TurboStreamPresenter.new(source: @source, responder: @responder)
      end

      test "render_deletion removes source row" do
        metrics = mock_metrics
        query = mock_query(exists: true)

        @presenter.render_deletion(metrics:, query:, search_params: {})

        # Verify responder was called to remove the row
        operations = @responder.operations
        remove_operation = operations.find { |op| op.action == :remove }

        assert remove_operation, "Expected remove operation to be added"
        # ActionView::RecordIdentifier.dom_id generates "row_source_#{id}" format
        assert_equal "row_source_#{@source.id}", remove_operation.target
      end

      test "render_deletion updates heatmap" do
        metrics = mock_metrics
        query = mock_query(exists: true)

        @presenter.render_deletion(metrics:, query:, search_params: { "foo" => "bar" })

        # Verify heatmap replace operation
        operations = @responder.operations
        heatmap_operation = operations.find { |op| op.target == "source_monitor_sources_heatmap" }

        assert heatmap_operation, "Expected heatmap update operation"
        assert_equal :replace, heatmap_operation.action
        assert_equal "source_monitor/sources/fetch_interval_heatmap", heatmap_operation.partial
      end

      test "render_deletion adds empty state when no sources exist" do
        metrics = mock_metrics
        query = mock_query(exists: false)

        @presenter.render_deletion(metrics:, query:, search_params: {})

        # Verify empty state append operation
        operations = @responder.operations
        empty_state_operation = operations.find { |op| op.target == "source_monitor_sources_table_body" }

        assert empty_state_operation, "Expected empty state operation when no sources exist"
        assert_equal :append, empty_state_operation.action
      end

      test "render_deletion does not add empty state when sources still exist" do
        metrics = mock_metrics
        query = mock_query(exists: true)

        @presenter.render_deletion(metrics:, query:, search_params: {})

        # Verify no empty state operation
        operations = @responder.operations
        empty_state_operation = operations.find { |op| op.target == "source_monitor_sources_table_body" }

        refute empty_state_operation, "Should not add empty state when sources still exist"
      end

      test "render_deletion adds redirect when location provided" do
        metrics = mock_metrics
        query = mock_query(exists: true)
        redirect_location = "/source_monitor/sources"

        @presenter.render_deletion(metrics:, query:, search_params: {}, redirect_location:)

        # Verify redirect operation
        operations = @responder.operations
        redirect_operation = operations.find { |op| op.action == :redirect }

        assert redirect_operation, "Expected redirect operation when location provided"
        assert_equal redirect_location, redirect_operation.locals[:url]
      end

      test "render_deletion skips redirect when location is nil" do
        metrics = mock_metrics
        query = mock_query(exists: true)

        @presenter.render_deletion(metrics:, query:, search_params: {}, redirect_location: nil)

        # Verify no redirect operation
        operations = @responder.operations
        redirect_operation = operations.find { |op| op.action == :redirect }

        refute redirect_operation, "Should not add redirect when location is nil"
      end

      private

      def mock_metrics
        Struct.new(:fetch_interval_distribution, :selected_fetch_interval_bucket).new(
          [],
          nil
        )
      end

      def mock_query(exists:)
        Struct.new(:result).new(
          Struct.new(:exists?).new(exists)
        )
      end
    end
  end
end
