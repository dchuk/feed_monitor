# frozen_string_literal: true

require "active_support/core_ext/string/inflections"

module SourceMonitor
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
        definition = SourceMonitor.config.models.for(entry.key)

        assign_table_name(entry)
        apply_concerns(entry.model_class, definition)
        apply_validations(entry.model_class, definition)
      end

      def assign_table_name(entry)
        model_class = entry.model_class
        desired = "#{SourceMonitor.table_name_prefix}#{entry.base_table}"
        model_class.table_name = desired
      end

      def apply_concerns(model_class, definition)
        applied = model_class.instance_variable_get(:@_source_monitor_extension_concerns) || []

        definition.each_concern do |signature, mod|
          next if applied.include?(signature)

          model_class.include(mod) unless model_class < mod
          applied << signature
        end

        model_class.instance_variable_set(:@_source_monitor_extension_concerns, applied)
      end

      def apply_validations(model_class, definition)
        remove_extension_validations(model_class)

        applied_signatures = []
        applied_filters = []

        definition.validations.each do |validation|
          signature = validation.signature
          next if applied_signatures.include?(signature)

          if validation.symbol?
            model_class.validate(validation.handler, **validation.options)
            applied_filters << validation.handler
          else
            handler = validation.handler
            callback = proc { |record| handler.call(record) }
            model_class.validate(**validation.options, &callback)
            applied_filters << callback
          end

          applied_signatures << signature
        end

        model_class.instance_variable_set(:@_source_monitor_extension_validations, applied_signatures)
        model_class.instance_variable_set(:@_source_monitor_extension_validation_filters, applied_filters)
      end

      def base_table_name_for(model_class)
        model_class.name.demodulize.tableize
      end

      def remove_extension_validations(model_class)
        filters = model_class.instance_variable_get(:@_source_monitor_extension_validation_filters)
        return unless filters&.any?

        callbacks = model_class._validate_callbacks
        return unless callbacks

        callbacks.to_a.each do |callback|
          callbacks.delete(callback) if filters.include?(callback.filter)
        end

        model_class.instance_variable_set(:@_source_monitor_extension_validations, [])
        model_class.instance_variable_set(:@_source_monitor_extension_validation_filters, [])
      end
    end
  end
end
