# frozen_string_literal: true

require "action_view"

module Feedmon
  module Security
    module ParameterSanitizer
      module_function

      def sanitize(value)
        case value
        when ActionController::Parameters
          sanitize(value.to_unsafe_h)
        when Hash
          value.each_with_object({}) do |(key, val), memo|
            memo[key] = sanitize(val)
          end
        when Array
          value.map { |element| sanitize(element) }
        when String
          sanitize_string(value)
        else
          value
        end
      end

      def sanitize_string(value)
        stripped = value.to_s
        return stripped if stripped.blank?

        sanitized = full_sanitizer.sanitize(stripped)
        sanitized.strip
      end
      private_class_method :sanitize_string

      def full_sanitizer
        @full_sanitizer ||= ActionView::Base.full_sanitizer
      end
      private_class_method :full_sanitizer
    end
  end
end
