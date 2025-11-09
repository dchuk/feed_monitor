# frozen_string_literal: true

require "action_view"

module SourceMonitor
  module Realtime
    module Broadcaster
      extend self
      extend ActionView::RecordIdentifier

      SOURCE_INDEX_STREAM = "source_monitor_sources"
      NOTIFICATION_STREAM = "source_monitor_notifications"

      def setup!
        return unless turbo_available?
        return if @setup

        register_callback(:after_fetch_completed, fetch_callback)
        register_callback(:after_item_scraped, item_callback)

        @setup = true
      end

      def fetch_callback
        @fetch_callback ||= lambda { |event| handle_fetch_completed(event) }
      end

      def item_callback
        @item_callback ||= lambda { |event| handle_item_scraped(event) }
      end

      def broadcast_source(source)
        return unless turbo_available?
        source = reload_record(source)
        return unless source

        broadcast_source_row(source)
        broadcast_source_show(source)
      end

      def broadcast_item(item)
        return unless turbo_available?
        item = reload_record(item)
        return unless item

        Turbo::StreamsChannel.broadcast_replace_to(
          item,
          :details,
          target: dom_id(item, :details),
          html: render_html = SourceMonitor::ItemsController.render(
            partial: "source_monitor/items/details_wrapper",
            locals: { item: item }
          )
        )
        log_info(
          "broadcast_item",
          item_id: item.id,
          stream: item_stream_identifier(item),
          status: item.scrape_status,
          contains_scraped_label: render_html.include?("Scraped")
        )
      rescue StandardError => error
        log_error("item broadcast", error)
      end

      def broadcast_toast(message:, level: :info, title: nil, delay_ms: 5000)
        return unless turbo_available?
        return if message.blank?

        Turbo::StreamsChannel.broadcast_append_to(
          NOTIFICATION_STREAM,
          target: NOTIFICATION_STREAM,
          html: SourceMonitor::ApplicationController.render(
            partial: "source_monitor/shared/toast",
            locals: {
              message: message,
              level: level,
              title: title,
              delay_ms: delay_ms
            }
          )
        )
      rescue StandardError => error
        log_error("toast broadcast", error)
      end

      private

      def handle_fetch_completed(event)
        source = event&.source
        return unless source

        broadcast_source(source)
        broadcast_fetch_toast(event)
      end

      def handle_item_scraped(event)
        item = event&.item
        return unless item

        broadcast_item(item)
        broadcast_source(event&.source || item.source)
        broadcast_item_toast(event)
      end

      def broadcast_fetch_toast(event)
        return unless event
        source = event.source
        status = event.status.to_s

        case status
        when "fetched"
          processing = event.result&.item_processing
          created = processing&.created.to_i
          updated = processing&.updated.to_i
          broadcast_toast(
            message: "Fetched #{source.name} (#{created} created, #{updated} updated).",
            level: :success
          )
        when "not_modified"
          broadcast_toast(
            message: "#{source.name} is up to date.",
            level: :info
          )
        when "failed"
          error_message = event.result&.error&.message ||
            source.last_error ||
            "Fetch failed"
          broadcast_toast(
            message: "Fetch failed for #{source.name}: #{error_message}",
            level: :error,
            delay_ms: 6000
          )
        end
      end

      def broadcast_item_toast(event)
        return unless event
        item = event.item
        source = event.source
        title = item&.title.presence || "Feed item"

        if event.status.to_s == "failed"
          message = "Scrape failed for #{title}"
          message += " (#{source.name})" if source
          broadcast_toast(message:, level: :error, delay_ms: 6000)
        else
          message = "Scrape completed for #{title}"
          message += " (#{source.name})" if source
          broadcast_toast(message:, level: :success)
        end
      end

      def broadcast_source_row(source)
        Turbo::StreamsChannel.broadcast_replace_to(
          SOURCE_INDEX_STREAM,
          target: dom_id(source, :row),
          html: SourceMonitor::SourcesController.render(
            partial: "source_monitor/sources/row",
            locals: {
              source: source,
              activity_rate: SourceMonitor::Analytics::SourceActivityRates.rate_for(source)
            }
          )
        )
      rescue StandardError => error
        log_error("source row broadcast", error)
      end

      def broadcast_source_show(source)
        Turbo::StreamsChannel.broadcast_replace_to(
          source,
          :details,
          target: dom_id(source, :details),
          html: SourceMonitor::SourcesController.render(
            partial: "source_monitor/sources/details_wrapper",
            locals: { source: source }
          )
        )
        log_info(
          "broadcast_source_show",
          source_id: source.id,
          stream: source_stream_identifier(source),
          status: source.fetch_status
        )
      rescue StandardError => error
        log_error("source show broadcast", error)
      end

      def reload_record(record)
        return unless record

        record.reload
      rescue StandardError
        record
      end

      def log_info(stage, **extra)
        return unless defined?(Rails) && Rails.respond_to?(:logger) && Rails.logger

        payload = {
          stage: "SourceMonitor::Realtime::Broadcaster##{stage}"
        }.merge(extra.compact)
        Rails.logger.info("[SourceMonitor::ManualScrape] #{payload.to_json}")
      rescue StandardError
        nil
      end

      def item_stream_identifier(item)
        Turbo::StreamsChannel.signed_stream_name([ item, :details ]) rescue nil
      end

      def source_stream_identifier(source)
        Turbo::StreamsChannel.signed_stream_name([ source, :details ]) rescue nil
      end

      def turbo_available?
        defined?(Turbo::StreamsChannel)
      end

      def register_callback(name, callback)
        callbacks = SourceMonitor.config.events.callbacks_for(name)
        return if callbacks.include?(callback)

        SourceMonitor.config.events.public_send(name, callback)
      end

      def log_error(context, error)
        Rails.logger.error(
          "[SourceMonitor] Realtime #{context} failed: #{error.class}: #{error.message}"
        ) if defined?(Rails) && Rails.respond_to?(:logger) && Rails.logger
      rescue StandardError
        nil
      end
    end
  end
end
