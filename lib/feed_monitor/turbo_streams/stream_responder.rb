# frozen_string_literal: true

module FeedMonitor
  module TurboStreams
    class StreamResponder
      Operation = Struct.new(:action, :target, :partial, :locals, keyword_init: true)

      include ActionView::RecordIdentifier

      attr_reader :operations

      def initialize
        @operations = []
      end

      def replace(target, partial:, locals: {})
        operations << Operation.new(action: :replace, target:, partial:, locals:)
        self
      end

      def append(target, partial:, locals: {})
        operations << Operation.new(action: :append, target:, partial:, locals:)
        self
      end

      def replace_details(record, partial:, locals: {})
        replace(dom_id(record, :details), partial:, locals:)
      end

      def replace_row(record, partial:, locals: {})
        replace(dom_id(record, :row), partial:, locals:)
      end

      def remove(target)
        operations << Operation.new(action: :remove, target:, partial: nil, locals: nil)
        self
      end

      def remove_row(record)
        remove(dom_id(record, :row))
      end

      def toast(message:, level: :info, title: nil, delay_ms: 5000)
        append(
          "feed_monitor_notifications",
          partial: "feed_monitor/shared/toast",
          locals: {
            message:,
            level: level || :info,
            title:,
            delay_ms: delay_ms || 5000
          }
        )
      end

      def render(view_context)
        operations.map do |operation|
          if operation.partial
            view_context.turbo_stream.public_send(
              operation.action,
              operation.target,
              partial: operation.partial,
              locals: operation.locals || {}
            )
          else
            view_context.turbo_stream.public_send(
              operation.action,
              operation.target
            )
          end
        end
      end
    end
  end
end
