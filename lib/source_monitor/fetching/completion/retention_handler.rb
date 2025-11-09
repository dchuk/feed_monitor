# frozen_string_literal: true

module SourceMonitor
  module Fetching
    module Completion
      # Applies item retention after a fetch completes.
      class RetentionHandler
        def initialize(pruner: SourceMonitor::Items::RetentionPruner)
          @pruner = pruner
        end

        def call(source:, result:) # rubocop:disable Lint/UnusedMethodArgument
          pruner.call(
            source: source,
            strategy: SourceMonitor.config.retention.strategy
          )
        rescue StandardError => error
          Rails.logger.error(
            "[SourceMonitor] Retention pruning failed for source #{source.id}: #{error.class} - #{error.message}"
          )
          nil
        end

        private

        attr_reader :pruner
      end
    end
  end
end
