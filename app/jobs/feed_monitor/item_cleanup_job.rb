# frozen_string_literal: true

module FeedMonitor
  class ItemCleanupJob < ApplicationJob
    DEFAULT_BATCH_SIZE = 100

    feed_monitor_queue :fetch

    def perform(options = nil)
      options = normalize_options(options)

      scope = resolve_scope(options)
      batch_size = resolve_batch_size(options)
      now = resolve_time(options[:now])
      strategy = resolve_strategy(options)
      pruner_class = options[:retention_pruner_class] || FeedMonitor::Items::RetentionPruner

      scope.find_in_batches(batch_size:) do |batch|
        batch.each do |source|
          pruner_class.call(source:, now:, strategy:)
        end
      end
    end

    private

    def normalize_options(options)
      case options
      when nil
        {}
      when Hash
        options.respond_to?(:symbolize_keys) ? options.symbolize_keys : options
      else
        {}
      end
    end

    def resolve_scope(options)
      relation = options[:source_scope] || FeedMonitor::Source.all
      ids = extract_ids(options)

      if ids.any?
        relation.where(id: ids)
      else
        relation
      end
    end

    def extract_ids(options)
      ids = Array(options[:source_ids] || options[:source_id])
      ids = ids.flat_map { |value| value.to_s.split(",") }
      ids.map!(&:strip)
      ids.reject!(&:blank?)
      ids.map! { |value| value.to_i }
      ids.reject!(&:zero?)
      ids
    end

    def resolve_batch_size(options)
      value = options[:batch_size]
      value = value.to_i if value.respond_to?(:to_i)
      value = nil if value && value <= 0
      value || DEFAULT_BATCH_SIZE
    end

    def resolve_time(value)
      case value
      when nil
        Time.current
      when Time
        value
      when String
        Time.zone.parse(value) || Time.current
      else
        value.respond_to?(:to_time) ? value.to_time : Time.current
      end
    end

    def resolve_strategy(options)
      if options.key?(:strategy)
        options[:strategy]
      elsif options.key?(:soft_delete)
        ActiveModel::Type::Boolean.new.cast(options[:soft_delete]) ? :soft_delete : :destroy
      else
        FeedMonitor.config.retention.strategy
      end
    end
  end
end
