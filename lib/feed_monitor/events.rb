# frozen_string_literal: true

require "active_support/core_ext/time"

module FeedMonitor
  module Events
    ItemCreatedEvent = Struct.new(:item, :source, :entry, :result, :status, :occurred_at, keyword_init: true) do
      def created?
        status.to_s == "created"
      end
    end

    ItemScrapedEvent = Struct.new(:item, :source, :result, :log, :status, :occurred_at, keyword_init: true) do
      def success?
        status.to_s != "failed"
      end
    end

    FetchCompletedEvent = Struct.new(:source, :result, :status, :occurred_at, keyword_init: true)

    ItemProcessorContext = Struct.new(:item, :source, :entry, :result, :status, :occurred_at, keyword_init: true)

    module_function

    def after_item_created(item:, source:, entry:, result:)
      event = ItemCreatedEvent.new(
        item: item,
        source: source,
        entry: entry,
        result: result,
        status: result&.status,
        occurred_at: Time.current
      )

      dispatch(:after_item_created, event)
    end

    def after_item_scraped(result)
      item = result&.item
      source = item&.source
      event = ItemScrapedEvent.new(
        item: item,
        source: source,
        result: result,
        log: result&.log,
        status: result&.status,
        occurred_at: Time.current
      )

      dispatch(:after_item_scraped, event)
    end

    def after_fetch_completed(source:, result:)
      event = FetchCompletedEvent.new(
        source: source,
        result: result,
        status: result&.status,
        occurred_at: Time.current
      )

      dispatch(:after_fetch_completed, event)
    end

    def run_item_processors(source:, entry:, result:)
      item = result&.item
      context = ItemProcessorContext.new(
        item: item,
        source: source,
        entry: entry,
        result: result,
        status: result&.status,
        occurred_at: Time.current
      )

      FeedMonitor.config.events.item_processors.each do |processor|
        invoke(processor, context)
      rescue StandardError => error
        log_handler_error(:item_processor, processor, error)
      end
    end

    def dispatch(event_name, event)
      FeedMonitor.config.events.callbacks_for(event_name).each do |callback|
        invoke(callback, event)
      rescue StandardError => error
        log_handler_error(event_name, callback, error)
      end
    end

    def invoke(callable, event)
      if callable.respond_to?(:arity) && callable.arity.zero?
        callable.call
      else
        callable.call(event)
      end
    end

    def log_handler_error(kind, handler, error)
      message = "[FeedMonitor] #{kind} handler #{handler.inspect} failed: #{error.class}: #{error.message}"

      if defined?(Rails) && Rails.respond_to?(:logger) && Rails.logger
        Rails.logger.error(message)
      else
        warn(message)
      end
    rescue StandardError
      warn(message)
    end
  end
end
