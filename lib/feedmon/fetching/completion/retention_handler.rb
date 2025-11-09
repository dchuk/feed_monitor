# frozen_string_literal: true

module Feedmon
  module Fetching
    module Completion
      # Applies item retention after a fetch completes.
      class RetentionHandler
        def initialize(pruner: Feedmon::Items::RetentionPruner)
          @pruner = pruner
        end

        def call(source:, result:) # rubocop:disable Lint/UnusedMethodArgument
          pruner.call(
            source: source,
            strategy: Feedmon.config.retention.strategy
          )
        rescue StandardError => error
          Rails.logger.error(
            "[Feedmon] Retention pruning failed for source #{source.id}: #{error.class} - #{error.message}"
          )
          nil
        end

        private

        attr_reader :pruner
      end
    end
  end
end
