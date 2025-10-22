# frozen_string_literal: true

module FeedMonitor
  class SourceHealthCheckJob < ApplicationJob
    feed_monitor_queue :fetch

    discard_on ActiveJob::DeserializationError

    def perform(source_id)
      source = FeedMonitor::Source.find_by(id: source_id)
      return unless source

      FeedMonitor::Health::SourceHealthCheck.new(source: source).call
    rescue StandardError => error
      Rails.logger&.error(
        "[FeedMonitor::SourceHealthCheckJob] error for source #{source_id}: #{error.class}: #{error.message}"
      ) if defined?(Rails) && Rails.respond_to?(:logger)

      record_unexpected_failure(source, error) if source
      nil
    end

    private

    def record_unexpected_failure(source, error)
      FeedMonitor::HealthCheckLog.create!(
        source: source,
        success: false,
        started_at: Time.current,
        completed_at: Time.current,
        duration_ms: 0,
        error_class: error.class.name,
        error_message: error.message
      )
    rescue StandardError
      nil
    end
  end
end
