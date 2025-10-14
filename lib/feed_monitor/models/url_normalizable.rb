# frozen_string_literal: true

require "active_support/concern"
require "active_support/core_ext/object/blank"
require "uri"

module FeedMonitor
  module Models
    module UrlNormalizable
      extend ActiveSupport::Concern

      included do
        class_attribute :normalized_url_attributes, instance_writer: false, default: []
      end

      class_methods do
        def normalizes_urls(*attributes)
          return if attributes.empty?

          before_validation :normalize_configured_urls
          self.normalized_url_attributes += attributes.map(&:to_sym)
          self.normalized_url_attributes.uniq!
        end

        def validates_url_format(*attributes)
          attributes.each do |attribute|
            validate_method = :"validate_#{attribute}_format"

            define_method validate_method do
              return if self[attribute].blank?

              errors.add(attribute, "must be a valid HTTP(S) URL") if url_invalid?(attribute)
            end

            validate validate_method
          end
        end
      end

      def url_invalid?(attribute)
        invalid_urls[attribute.to_sym]
      end

      private

      def normalize_configured_urls
        normalized_url_attributes.each do |attribute|
          normalize_single_url(attribute)
        end
      end

      def normalize_single_url(attribute)
        raw_value = self[attribute]
        invalid_urls[attribute] = false

        normalized = normalize_url_value(raw_value)
        self[attribute] = normalized
      rescue URI::InvalidURIError
        invalid_urls[attribute] = true
      end

      def normalize_url_value(value)
        return nil if value.blank?

        uri = URI.parse(value.to_s.strip)
        raise URI::InvalidURIError if uri.scheme.blank? || uri.host.blank?

        scheme = uri.scheme.downcase
        raise URI::InvalidURIError unless %w[http https].include?(scheme)

        uri.scheme = scheme
        uri.host = uri.host.downcase
        uri.path = "/" if uri.path.blank?
        uri.fragment = nil

        uri.to_s
      end

      def invalid_urls
        @_feed_monitor_invalid_urls ||= Hash.new(false)
      end
    end
  end
end
