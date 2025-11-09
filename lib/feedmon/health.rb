# frozen_string_literal: true

require "feedmon/health/source_health_monitor"
require "feedmon/health/source_health_reset"
require "feedmon/health/source_health_check"

module Feedmon
  module Health
    module_function

    def setup!
      register_fetch_callback
    end

    def fetch_callback
      @fetch_callback ||= lambda do |event|
        source = event&.source
        next unless source

        SourceHealthMonitor.new(source: source).call
      rescue StandardError => error
        log_error(source, error)
      end
    end

    def register_fetch_callback
      callbacks = Feedmon.config.events.callbacks_for(:after_fetch_completed)
      return if callbacks.include?(fetch_callback)

      Feedmon.config.events.after_fetch_completed(fetch_callback)
    end
    private_class_method :register_fetch_callback

    def log_error(source, error)
      message = "[Feedmon] Source health monitor failed for #{source&.id || 'unknown'}: #{error.class}: #{error.message}"
      if defined?(Rails) && Rails.respond_to?(:logger) && Rails.logger
        Rails.logger.error(message)
      else
        warn(message)
      end
    rescue StandardError
      warn(message)
    end
    private_class_method :log_error
  end
end
