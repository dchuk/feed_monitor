# frozen_string_literal: true

module FeedMonitor
  class FetchFeedJob < ApplicationJob
    FETCH_CONCURRENCY_RETRY_WAIT = 30.seconds
    EARLY_EXECUTION_LEEWAY = 30.seconds

    feed_monitor_queue :fetch

    discard_on ActiveJob::DeserializationError
    retry_on FeedMonitor::Fetching::FetchRunner::ConcurrencyError,
             wait: FETCH_CONCURRENCY_RETRY_WAIT,
             attempts: 5

    def perform(source_id, force: false)
      source = FeedMonitor::Source.find_by(id: source_id)
      return unless source

      return unless should_run?(source, force: force)

      FeedMonitor::Fetching::FetchRunner.new(source: source, force: force).run
    rescue FeedMonitor::Fetching::FetchError => error
      handle_transient_error(source, error)
    end

    private

    def should_run?(source, force:)
      return true if force

      status = source.fetch_status.to_s
      return true if %w[queued fetching].include?(status)

      next_fetch_at = source.next_fetch_at
      return true if next_fetch_at.blank?

      next_fetch_at <= Time.current + EARLY_EXECUTION_LEEWAY
    end

    def handle_transient_error(source, error)
      raise error unless transient_error?(error) && source

      decision = FeedMonitor::Fetching::RetryPolicy.new(source:, error:, now: Time.current).decision
      return raise error unless decision

      if decision.retry?
        enqueue_retry!(source, decision)
      elsif decision.open_circuit?
        open_circuit!(source, decision)
        raise error
      else
        reset_retry_state!(source)
        raise error
      end
    rescue StandardError => policy_error
      log_retry_failure(source, error, policy_error)
      raise error
    end

    def enqueue_retry!(source, decision)
      retry_at = Time.current + (decision.wait || 0)

      source.with_lock do
        source.reload
        source.update!(
          fetch_retry_attempt: decision.next_attempt,
          fetch_circuit_opened_at: nil,
          fetch_circuit_until: nil,
          next_fetch_at: retry_at,
          backoff_until: retry_at,
          fetch_status: "queued"
        )
      end

      retry_job wait: decision.wait || 0
    end

    def open_circuit!(source, decision)
      source.with_lock do
        source.reload
        source.update!(
          fetch_retry_attempt: 0,
          fetch_circuit_opened_at: Time.current,
          fetch_circuit_until: decision.circuit_until,
          next_fetch_at: decision.circuit_until,
          backoff_until: decision.circuit_until,
          fetch_status: "failed"
        )
      end
    end

    def reset_retry_state!(source)
      source.with_lock do
        source.reload
        source.update!(
          fetch_retry_attempt: 0,
          fetch_circuit_opened_at: nil,
          fetch_circuit_until: nil
        )
      end
    end

    def transient_error?(error)
      error.is_a?(FeedMonitor::Fetching::FetchError)
    end

    def log_retry_failure(source, original_error, policy_error)
      return unless defined?(Rails) && Rails.respond_to?(:logger) && Rails.logger

      message = "[FeedMonitor::FetchFeedJob] Failed to schedule retry for source #{source&.id}: " \
                "#{original_error.class}: #{original_error.message} (policy error: #{policy_error.class})"
      Rails.logger.error(message)
    rescue StandardError
      nil
    end
  end
end
