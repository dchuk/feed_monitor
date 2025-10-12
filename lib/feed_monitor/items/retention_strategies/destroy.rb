# frozen_string_literal: true

module FeedMonitor
  module Items
    module RetentionStrategies
      class Destroy
        def initialize(source:)
          @source = source
        end

        def apply(batch:, now: Time.current) # rubocop:disable Lint/UnusedMethodArgument
          count = 0
          batch.each do |item|
            item.destroy!
            count += 1
          end
          count
        end

        private

        attr_reader :source
      end
    end
  end
end

