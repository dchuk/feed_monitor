# frozen_string_literal: true

require "time"

module FeedMonitor
  module Jobs
    module CleanupOptions
      module_function

      def normalize(options)
        case options
        when nil
          {}
        when Hash
          options.respond_to?(:symbolize_keys) ? options.symbolize_keys : symbolize_keys(options)
        else
          {}
        end
      end

      def resolve_time(value, default: Time.current)
        case value
        when nil
          default
        when Time
          value
        when String
          parse_time(value, default)
        else
          value.respond_to?(:to_time) ? value.to_time : default
        end
      end

      def extract_ids(value)
        Array(value)
          .flat_map do |entry|
            case entry
            when Integer
              [entry]
            when Array
              entry
            else
              entry.to_s.split(",")
            end
          end
          .map { |entry| entry.is_a?(String) ? entry.strip : entry }
          .reject { |entry| entry.respond_to?(:blank?) ? entry.blank? : entry.nil? }
          .map { |entry| integer(entry) }
          .compact
          .reject(&:zero?)
      end

      def integer(value)
        return value if value.is_a?(Integer)

        Integer(value, exception: false)
      end

      def batch_size(options, default:)
        value = integer(options[:batch_size])
        return default unless value&.positive?

        value
      end

      def symbolize_keys(hash)
        hash.each_with_object({}) do |(key, value), memo|
          memo[key.respond_to?(:to_sym) ? key.to_sym : key] = value
        end
      end
      private_class_method :symbolize_keys

      def parse_time(value, default)
        if Time.zone
          Time.zone.parse(value) || default
        else
          Time.parse(value)
        end
      rescue ArgumentError, TypeError
        default
      end
      private_class_method :parse_time
    end
  end
end
