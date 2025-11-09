# frozen_string_literal: true

require "test_helper"

module SourceMonitor
  module Analytics
    class SourcesIndexMetricsTest < ActiveSupport::TestCase
      setup do
        SourceMonitor::ScrapeLog.delete_all
        SourceMonitor::FetchLog.delete_all
        SourceMonitor::Item.delete_all
        SourceMonitor::Source.delete_all

        travel_to Time.current.change(usec: 0)

        @fast_source = create_source!(name: "Fast", fetch_interval_minutes: 30)
        @medium_source = create_source!(name: "Medium", fetch_interval_minutes: 120)
        @slow_source = create_source!(name: "Slow", fetch_interval_minutes: 480)

        SourceMonitor::Item.create!(
          source: @fast_source,
          guid: SecureRandom.uuid,
          url: "https://example.com/fast-1",
          title: "Fast 1",
          created_at: 1.day.ago,
          published_at: 1.day.ago
        )

        SourceMonitor::Item.create!(
          source: @fast_source,
          guid: SecureRandom.uuid,
          url: "https://example.com/fast-2",
          title: "Fast 2",
          created_at: 2.days.ago,
          published_at: 2.days.ago
        )

        SourceMonitor::Item.create!(
          source: @medium_source,
          guid: SecureRandom.uuid,
          url: "https://example.com/medium-1",
          title: "Medium 1",
          created_at: 12.hours.ago,
          published_at: 12.hours.ago
        )
      end

      teardown do
        travel_back
      end

      test "computes fetch interval distribution and activity rates" do
        scope = SourceMonitor::Source.all
        metrics = SourceMonitor::Analytics::SourcesIndexMetrics.new(
          base_scope: scope,
          result_scope: scope,
          search_params: {},
          lookback: 2.days,
          now: Time.current
        )

        distribution = metrics.fetch_interval_distribution
        assert distribution.any? { |bucket| bucket.label == "30-60 min" && bucket.count == 1 }
        assert distribution.any? { |bucket| bucket.label == "120-240 min" && bucket.count == 1 }
        assert distribution.any? { |bucket| bucket.label == "480+ min" && bucket.count == 1 }

        activity_rates = metrics.item_activity_rates
        assert_in_delta 1.0, activity_rates[@fast_source.id], 0.01
        assert_in_delta 0.5, activity_rates[@medium_source.id], 0.01
        assert_in_delta 0.0, activity_rates[@slow_source.id], 0.01
      end

      test "selects fetch interval bucket based on sanitized filter" do
        scope = SourceMonitor::Source.all
        metrics = SourceMonitor::Analytics::SourcesIndexMetrics.new(
          base_scope: scope,
          result_scope: scope,
          search_params: {
            "fetch_interval_minutes_gteq" => "60",
            "fetch_interval_minutes_lt" => "120<script>"
          },
          lookback: 2.days,
          now: Time.current
        )

        bucket = metrics.selected_fetch_interval_bucket

        assert_equal 60, bucket.min
        assert_equal 120, bucket.max
      end

      test "excludes fetch interval filters when building distribution scope" do
        scope = SourceMonitor::Source.where(name: %w[Fast Medium Slow])
        metrics = SourceMonitor::Analytics::SourcesIndexMetrics.new(
          base_scope: scope,
          result_scope: scope,
          search_params: {
            "name_cont" => "Fast",
            "fetch_interval_minutes_gteq" => "60",
            "fetch_interval_minutes_lteq" => "90"
          },
          lookback: 2.days,
          now: Time.current
        )

        distribution_scope_ids = metrics.send(:distribution_source_ids)

        assert_includes distribution_scope_ids, @fast_source.id
        refute_includes distribution_scope_ids, @medium_source.id
      end
    end
  end
end
