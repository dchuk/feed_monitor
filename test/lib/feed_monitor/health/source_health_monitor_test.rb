# frozen_string_literal: true

require "test_helper"

module FeedMonitor
  module Health
    class SourceHealthMonitorTest < ActiveSupport::TestCase
      include ActiveSupport::Testing::TimeHelpers

      setup do
        FeedMonitor::FetchLog.delete_all
        FeedMonitor::Source.delete_all

        @source = FeedMonitor::Source.create!(
          name: "Health Source",
          feed_url: "https://example.com/healthy.xml",
          fetch_interval_minutes: 60,
          next_fetch_at: Time.current
        )

        configure_health(
          window_size: 5,
          healthy_threshold: 0.6,
          warning_threshold: 0.4,
          auto_pause_threshold: 0.2,
          auto_resume_threshold: 0.5,
          cooldown_minutes: 30
        )
      end

      teardown do
        restore_health_configuration
        travel_back
      end

      test "updates rolling success rate and health status" do
        travel_to Time.current

        3.times { |index| create_fetch_log(success: true, minutes_ago: index + 1) }
        2.times { |index| create_fetch_log(success: false, minutes_ago: index + 4) }

        FeedMonitor::Health::SourceHealthMonitor.new(source: @source).call

        @source.reload
        assert_in_delta 0.6, @source.rolling_success_rate, 0.001
        assert_equal "improving", @source.health_status
      end

      test "auto pauses when rolling success rate falls below threshold" do
        travel_to Time.current

        5.times { |index| create_fetch_log(success: false, minutes_ago: index + 1) }

        FeedMonitor::Health::SourceHealthMonitor.new(source: @source).call

        @source.reload
        assert_equal "auto_paused", @source.health_status
        assert_not_nil @source.auto_paused_at
        assert_not_nil @source.auto_paused_until
        assert_operator @source.auto_paused_until, :>, Time.current
        assert_in_delta @source.auto_paused_until, @source.next_fetch_at, 1
      end

      test "resumes automatically when success rate recovers" do
        travel_to Time.current

        5.times { |index| create_fetch_log(success: false, minutes_ago: index + 1) }
        FeedMonitor::Health::SourceHealthMonitor.new(source: @source).call

        travel 31.minutes

        5.times { |index| create_fetch_log(success: true, minutes_ago: index) }

        FeedMonitor::Health::SourceHealthMonitor.new(source: @source).call

        @source.reload
        assert_equal "healthy", @source.health_status
        assert_nil @source.auto_paused_at
        assert_nil @source.auto_paused_until
      end

      test "uses per source auto pause threshold when provided" do
        @source.update!(health_auto_pause_threshold: 0.6)

        travel_to Time.current

        2.times { create_fetch_log(success: true) }
        3.times { create_fetch_log(success: false) }

        FeedMonitor::Health::SourceHealthMonitor.new(source: @source).call

        @source.reload
        assert_equal "auto_paused", @source.health_status
      end

      test "marks source as declining after three consecutive failures" do
        travel_to Time.current

        3.times { |index| create_fetch_log(success: false, minutes_ago: index) }

        FeedMonitor::Health::SourceHealthMonitor.new(source: @source).call

        @source.reload
        assert_equal "declining", @source.health_status
      end

      test "marks source as improving after consecutive recoveries" do
        travel_to Time.current

        create_fetch_log(success: false, minutes_ago: 2)
        create_fetch_log(success: true, minutes_ago: 1)
        create_fetch_log(success: true, minutes_ago: 0)

        FeedMonitor::Health::SourceHealthMonitor.new(source: @source).call

        @source.reload
        assert_equal "improving", @source.health_status
      end

      private

      def create_fetch_log(success:, minutes_ago: 0)
        started_at = Time.current - minutes_ago.minutes

        FeedMonitor::FetchLog.create!(
          source: @source,
          success: success,
          started_at: started_at,
          completed_at: started_at + 30.seconds,
          duration_ms: 30_000,
          http_status: success ? 200 : 500
        )
      end

      def configure_health(window_size:, healthy_threshold:, warning_threshold:, auto_pause_threshold:, auto_resume_threshold:, cooldown_minutes:)
        @previous_health_config = capture_health_configuration

        FeedMonitor.configure do |config|
          config.health.window_size = window_size
          config.health.healthy_threshold = healthy_threshold
          config.health.warning_threshold = warning_threshold
          config.health.auto_pause_threshold = auto_pause_threshold
          config.health.auto_resume_threshold = auto_resume_threshold
          config.health.auto_pause_cooldown_minutes = cooldown_minutes
        end
      end

      def restore_health_configuration
        return unless @previous_health_config

        FeedMonitor.configure do |config|
          config.health.window_size = @previous_health_config[:window_size]
          config.health.healthy_threshold = @previous_health_config[:healthy_threshold]
          config.health.warning_threshold = @previous_health_config[:warning_threshold]
          config.health.auto_pause_threshold = @previous_health_config[:auto_pause_threshold]
          config.health.auto_resume_threshold = @previous_health_config[:auto_resume_threshold]
          config.health.auto_pause_cooldown_minutes = @previous_health_config[:auto_pause_cooldown_minutes]
        end
      end

      def capture_health_configuration
        health = FeedMonitor.config.health
        {
          window_size: health.window_size,
          healthy_threshold: health.healthy_threshold,
          warning_threshold: health.warning_threshold,
          auto_pause_threshold: health.auto_pause_threshold,
          auto_resume_threshold: health.auto_resume_threshold,
          auto_pause_cooldown_minutes: health.auto_pause_cooldown_minutes
        }
      end
    end
  end
end
