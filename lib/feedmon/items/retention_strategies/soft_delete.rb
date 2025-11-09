# frozen_string_literal: true

module Feedmon
  module Items
    module RetentionStrategies
      class SoftDelete
        def initialize(source:)
          @source = source
        end

        def apply(batch:, now: Time.current)
          ids = Array(batch.pluck(:id))
          return 0 if ids.empty?

          timestamp = normalized_timestamp(now)

          # Use with_deleted to update items that may already be marked as deleted
          Feedmon::Item.with_deleted.where(id: ids).update_all(
            deleted_at: timestamp,
            updated_at: timestamp
          )

          adjust_source_counter(ids.length)
          ids.length
        end

        private

        attr_reader :source

        def normalized_timestamp(now)
          return Time.current if now.nil?

          now.respond_to?(:in_time_zone) ? now.in_time_zone : now
        end

        def adjust_source_counter(amount)
          return unless source&.id

          Feedmon::Source.update_counters(source.id, items_count: -amount)

          return unless source.respond_to?(:items_count) && !source.items_count.nil?

          source.items_count -= amount
          source.items_count = 0 if source.items_count.negative?
        end
      end
    end
  end
end
