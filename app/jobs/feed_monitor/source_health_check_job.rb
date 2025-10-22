# frozen_string_literal: true

module FeedMonitor
  class SourceHealthCheckJob < ApplicationJob
    feed_monitor_queue :fetch

    discard_on ActiveJob::DeserializationError

    def perform(source_id)
      source = FeedMonitor::Source.find_by(id: source_id)
      return unless source

      result = FeedMonitor::Health::SourceHealthCheck.new(source: source).call
      broadcast_outcome(source, result)
      result
    rescue StandardError => error
      Rails.logger&.error(
        "[FeedMonitor::SourceHealthCheckJob] error for source #{source_id}: #{error.class}: #{error.message}"
      ) if defined?(Rails) && Rails.respond_to?(:logger)

      record_unexpected_failure(source, error) if source
      broadcast_outcome(source, nil, error) if source
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

    def broadcast_outcome(source, result, error = nil)
      FeedMonitor::Realtime.broadcast_source(source)

      message, level = toast_payload(source, result, error)
      return if message.blank?

      FeedMonitor::Realtime.broadcast_toast(message:, level:)
    end

    def toast_payload(source, result, error)
      if error
        return [
          "Health check failed for #{source.name}: #{error.message}",
          :error
        ]
      end

      if result&.success?
        [
          "Health check succeeded for #{source.name}.",
          :success
        ]
      else
        failure_reason = result&.error&.message
        http_status = result&.log&.http_status
        message = "Health check failed for #{source.name}"
        message += " (HTTP #{http_status})" if http_status.present?
        message += ": #{failure_reason}" if failure_reason.present?
        [
          "#{message}.",
          :error
        ]
      end
    end
  end
end
