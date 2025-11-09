# frozen_string_literal: true

module Feedmon
  class ItemCleanupJob < ApplicationJob
    DEFAULT_BATCH_SIZE = 100

    feedmon_queue :fetch

    def perform(options = nil)
      options = Feedmon::Jobs::CleanupOptions.normalize(options)

      scope = resolve_scope(options)
      batch_size = Feedmon::Jobs::CleanupOptions.batch_size(options, default: DEFAULT_BATCH_SIZE)
      now = Feedmon::Jobs::CleanupOptions.resolve_time(options[:now])
      strategy = resolve_strategy(options)
      pruner_class = options[:retention_pruner_class] || Feedmon::Items::RetentionPruner

      scope.find_in_batches(batch_size:) do |batch|
        batch.each do |source|
          pruner_class.call(source:, now:, strategy:)
        end
      end
    end

    private

    def resolve_scope(options)
      relation = options[:source_scope] || Feedmon::Source.all
      ids = Feedmon::Jobs::CleanupOptions.extract_ids([ options[:source_ids], options[:source_id] ])

      if ids.any?
        relation.where(id: ids)
      else
        relation
      end
    end

    def resolve_strategy(options)
      if options.key?(:strategy)
        options[:strategy]
      elsif options.key?(:soft_delete)
        ActiveModel::Type::Boolean.new.cast(options[:soft_delete]) ? :soft_delete : :destroy
      else
        Feedmon.config.retention.strategy
      end
    end
  end
end
