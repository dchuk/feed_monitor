# frozen_string_literal: true

module SourceMonitor
  module Fetching
    module Completion
      # Publishes fetch completion events to the configured event dispatcher.
      class EventPublisher
        def initialize(dispatcher: SourceMonitor::Events)
          @dispatcher = dispatcher
        end

        def call(source:, result:)
          dispatcher.after_fetch_completed(source: source, result: result)
        end

        private

        attr_reader :dispatcher
      end
    end
  end
end
