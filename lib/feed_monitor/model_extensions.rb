# frozen_string_literal: true

require "active_support/core_ext/string/inflections"

module FeedMonitor
  module ModelExtensions
    class << self
      def register(model_class, key)
        key = key.to_sym
        registry[key] ||= []
        entry = registry[key].find { |registered| registered.model_class == model_class }

        unless entry
          entry = RegisteredModel.new(model_class, base_table_name_for(model_class), key)
          registry[key] << entry
        end

        apply_to(entry)
      end

      def reload!
        registry.each do |key, models|
          models.each { |entry| apply_to(entry) }
        end
      end

      private

      RegisteredModel = Struct.new(:model_class, :base_table, :key)

      def registry
        @registry ||= {}
      end

      def apply_to(entry)
        definition = FeedMonitor.config.models.for(entry.key)

        assign_table_name(entry)
        apply_concerns(entry.model_class, definition)
        apply_validations(entry.model_class, definition)
      end

      def assign_table_name(entry)
        model_class = entry.model_class
        desired = "#{FeedMonitor.table_name_prefix}#{entry.base_table}"
        model_class.table_name = desired
      end

      def apply_concerns(model_class, definition)
        applied = model_class.instance_variable_get(:@_feed_monitor_extension_concerns) || []

        definition.each_concern do |signature, mod|
          next if applied.include?(signature)

          model_class.include(mod) unless model_class < mod
          applied << signature
        end

        model_class.instance_variable_set(:@_feed_monitor_extension_concerns, applied)
      end

      def apply_validations(model_class, definition)
        applied = model_class.instance_variable_get(:@_feed_monitor_extension_validations) || []

        definition.validations.each do |validation|
          signature = validation.signature
          next if applied.include?(signature)

          if validation.symbol?
            model_class.validate(validation.handler, **validation.options)
          else
            handler = validation.handler
            model_class.validate(**validation.options) do |record|
              handler.call(record)
            end
          end

          applied << signature
        end

        model_class.instance_variable_set(:@_feed_monitor_extension_validations, applied)
      end

      def base_table_name_for(model_class)
        model_class.name.demodulize.tableize
      end
    end
  end
end
