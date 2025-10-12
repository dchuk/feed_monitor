# frozen_string_literal: true

require "active_support/concern"
require "active_support/hash_with_indifferent_access"

module FeedMonitor
  module Models
    module Sanitizable
      extend ActiveSupport::Concern

      included do
        class_attribute :sanitized_string_attributes, instance_writer: false, default: []
        class_attribute :sanitized_hash_attributes, instance_writer: false, default: []
      end

      class_methods do
        def sanitizes_string_attributes(*attributes)
          configure_sanitization_callback
          self.sanitized_string_attributes += attributes.map(&:to_sym)
          self.sanitized_string_attributes.uniq!
        end

        def sanitizes_hash_attributes(*attributes)
          configure_sanitization_callback
          self.sanitized_hash_attributes += attributes.map(&:to_sym)
          self.sanitized_hash_attributes.uniq!
        end

        private

        def configure_sanitization_callback
          return if @_feed_monitor_sanitization_callback_defined

          before_validation :sanitize_model_attributes
          @_feed_monitor_sanitization_callback_defined = true
        end
      end

      private

      def sanitize_model_attributes
        sanitizer = FeedMonitor::Security::ParameterSanitizer

        self.class.sanitized_string_attributes.each do |attribute|
          value = self[attribute]
          next unless value.is_a?(String)

          self[attribute] = sanitizer.sanitize(value)
        end

        self.class.sanitized_hash_attributes.each do |attribute|
          value = self[attribute] || {}
          sanitized = sanitizer.sanitize(value)
          self[attribute] = if sanitized.is_a?(Hash)
            to_indifferent_hash(sanitized)
          else
            ActiveSupport::HashWithIndifferentAccess.new
          end
        end
      end

      def to_indifferent_hash(value)
        case value
        when Hash
          value.each_with_object(ActiveSupport::HashWithIndifferentAccess.new) do |(key, val), memo|
            memo[key] = to_indifferent_hash(val)
          end
        when Array
          value.map { |element| to_indifferent_hash(element) }
        else
          value
        end
      end
    end
  end
end
