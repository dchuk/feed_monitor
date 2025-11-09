# frozen_string_literal: true

require "feedmon/instrumentation"
require "feedmon/items/retention_strategies"
require "feedmon/items/retention_strategies/destroy"
require "feedmon/items/retention_strategies/soft_delete"

module Feedmon
  module Items
    # Removes items that fall outside the configured retention rules for a source.
    # Supports age-based (items_retention_days) and count-based (max_items) limits.
    class RetentionPruner
      Result = Struct.new(:removed_by_age, :removed_by_limit, :removed_total, keyword_init: true) do
        def applied?
          removed_total.positive?
        end
      end

      STRATEGY_CLASSES = {
        destroy: Feedmon::Items::RetentionStrategies::Destroy,
        soft_delete: Feedmon::Items::RetentionStrategies::SoftDelete
      }.freeze

      def self.call(source:, now: Time.current, strategy: nil)
        new(source:, now:, strategy:).call
      end

      def initialize(source:, now: Time.current, strategy: nil)
        @source = source
        @now = now
        @strategy_name = normalize_strategy(strategy)
        @strategy_handler = STRATEGY_CLASSES.fetch(@strategy_name).new(source: source)
      end

      def call
        removed_by_age = prune_by_age
        removed_by_limit = prune_by_limit
        removed_total = removed_by_age + removed_by_limit

        if removed_total.positive?
          Feedmon::Instrumentation.item_retention(
            source_id: source.id,
            removed_by_age:,
            removed_by_limit:,
            removed_total:,
            items_retention_days: items_retention_days,
            max_items: max_items_limit
          )
        end

        Result.new(
          removed_by_age:,
          removed_by_limit:,
          removed_total:
        )
      end

      private

      attr_reader :source, :now, :strategy_name, :strategy_handler

      def prune_by_age
        days = items_retention_days
        return 0 unless days.present?

        return 0 if days <= 0

        cutoff = now - days.days

        timestamp_expression = Arel::Nodes::NamedFunction.new(
          "COALESCE",
          [
            Feedmon::Item.arel_table[:published_at],
            Feedmon::Item.arel_table[:created_at]
          ]
        )

        scope = source.items.where(timestamp_expression.lteq(cutoff))
        remove_scope(scope)
      end

      def prune_by_limit
        limit = max_items_limit
        return 0 unless limit.present?

        return 0 if limit <= 0

        ids_to_keep = source.items
          .order(Arel.sql("published_at DESC NULLS LAST, created_at DESC"))
          .limit(limit)
          .pluck(:id)

        scope =
          if ids_to_keep.empty?
            source.items.none
          else
            source.items.where.not(id: ids_to_keep)
          end

        remove_scope(scope)
      end

      def remove_scope(scope)
        return 0 if scope.none?

        removed = 0
        scope.in_batches(of: 100) do |batch|
          removed += strategy_handler.apply(batch:, now:)
        end
        removed
      end

      def normalize_strategy(value)
        value = Feedmon.config.retention.strategy if value.nil?

        value = value.to_sym if value.respond_to?(:to_sym)
        return value if STRATEGY_CLASSES.key?(value)

        valid = STRATEGY_CLASSES.keys.join(", ")
        raise ArgumentError, "Invalid retention strategy #{value.inspect}. Valid strategies: #{valid}"
      end

      def items_retention_days
        @items_retention_days ||= begin
          value = source.items_retention_days
          value = Feedmon.config.retention.items_retention_days if value.nil?
          convert_to_integer(value)
        end
      end

      def max_items_limit
        @max_items_limit ||= begin
          value = source.max_items
          value = Feedmon.config.retention.max_items if value.nil?
          convert_to_integer(value)
        end
      end

      def convert_to_integer(value)
        return nil if value.nil?

        value.respond_to?(:to_i) ? value.to_i : value
      end
    end
  end
end
