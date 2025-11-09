# frozen_string_literal: true

require "active_support/core_ext/hash/indifferent_access"
require "active_support/core_ext/hash/keys"

module SourceMonitor
  module Realtime
    module Adapter
      extend self

      FALLBACK_ADAPTERS = %i[async test].freeze

      def configure!
        return unless action_cable_available?

        desired_adapter = SourceMonitor.config.realtime.adapter
        return unless desired_adapter

        ensure_dependency!(desired_adapter)

        existing_config = current_config
        existing_adapter = extract_adapter(existing_config)

        if should_replace_adapter?(existing_adapter, desired_adapter)
          apply_configuration(SourceMonitor.config.realtime.action_cable_config)
        elsif same_adapter?(existing_adapter, desired_adapter)
          merge_defaults(existing_config, SourceMonitor.config.realtime.action_cable_config)
        end
      end

      private

      def action_cable_available?
        defined?(ActionCable) && ActionCable.respond_to?(:server)
      end

      def current_config
        ActionCable.server.config.cable || {}
      end

      def extract_adapter(config)
        adapter = config.is_a?(Hash) ? config[:adapter] || config["adapter"] : nil
        adapter&.to_sym
      end

      def should_replace_adapter?(existing_adapter, desired_adapter)
        return true if existing_adapter.nil?
        return true if FALLBACK_ADAPTERS.include?(existing_adapter)
        return true if desired_adapter && existing_adapter != desired_adapter

        false
      end

      def same_adapter?(existing_adapter, desired_adapter)
        existing_adapter && desired_adapter && existing_adapter == desired_adapter
      end

      def apply_configuration(raw_config)
        ActionCable.server.config.cable = normalize_config(raw_config)
      end

      def merge_defaults(existing_config, raw_config)
        defaults = normalize_config(raw_config)
        existing = normalize_config(existing_config)

        merged = defaults.merge(existing)
        ActionCable.server.config.cable = merged
      end

      def normalize_config(config)
        hash = config.to_h.deep_symbolize_keys
        hash[:adapter] = hash[:adapter].to_s if hash.key?(:adapter)
        hash.with_indifferent_access
      end

      def ensure_dependency!(adapter)
        case adapter.to_sym
        when :solid_cable
          require "solid_cable"
        when :redis
          require "redis"
        end
      rescue LoadError => error
        raise_missing_dependency_error(adapter, error)
      end

      def raise_missing_dependency_error(adapter, error)
        message = <<~ERROR.squish
          SourceMonitor realtime adapter #{adapter.inspect} could not be loaded: #{error.class}: #{error.message}.
          Ensure the corresponding gem is available or configure `SourceMonitor.config.realtime.adapter` with a supported backend.
        ERROR

        raise LoadError, message
      end
    end
  end
end
