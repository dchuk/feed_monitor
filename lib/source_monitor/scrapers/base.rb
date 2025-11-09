# frozen_string_literal: true

require "active_support/core_ext/hash/deep_merge"
require "active_support/hash_with_indifferent_access"
require "active_support/core_ext/hash/keys"

module SourceMonitor
  module Scrapers
    # Base class for content scrapers used by the engine.
    #
    # == Adapter Contract
    # Subclasses must implement #call and return a Result object describing the
    # outcome of a scrape attempt. Implementations receive an item, the owning
    # source, and a normalized settings hash that merges default adapter
    # settings, source-level overrides, and per-invocation overrides. All
    # adapters should remain stateless and thread-safe, relying on injected
    # collaborators (e.g. HTTP clients) instead of global configuration.
    #
    # Adapters should:
    # * Perform any outbound HTTP work using the provided +http+ client.
    # * Populate the Result with :html and :content payloads when successful.
    # * Use :status to communicate :success, :partial, or :failed outcomes.
    # * Capture additional diagnostics (headers, timings, etc.) in :metadata.
    class Base
      Result = Struct.new(:status, :html, :content, :metadata, keyword_init: true)

      class << self
        def call(item:, source:, settings: nil, http: SourceMonitor::HTTP)
          new(item: item, source: source, settings: settings, http: http).call
        end

        def adapter_name
          name.demodulize.sub(/Scraper\z/, "").underscore
        end

        def default_settings
          {}
        end
      end

      def initialize(item:, source:, settings: nil, http: SourceMonitor::HTTP)
        @item = item
        @source = source
        @http = http
        @settings = build_settings(settings)
      end

      def call
        raise NotImplementedError, "#{self.class.name} must implement #call"
      end

      protected

      attr_reader :item, :source, :http, :settings

      private

      def build_settings(overrides)
        combined = normalize_settings(self.class.default_settings)
          .deep_merge(normalize_settings(source_settings))

        if overrides.present? && overrides.respond_to?(:to_hash)
          combined = combined.deep_merge(normalize_settings(overrides.to_hash))
        end

        deep_indifferent_access(combined)
      end

      def source_settings
        value = source&.scrape_settings
        return {} unless value.respond_to?(:to_hash)

        value.to_hash
      end

      def deep_indifferent_access(value)
        case value
        when Hash
          value.each_with_object(ActiveSupport::HashWithIndifferentAccess.new) do |(key, val), memo|
            memo[key] = deep_indifferent_access(val)
          end
        when Array
          value.map { |element| deep_indifferent_access(element) }
        else
          value
        end
      end

      def normalize_settings(value)
        return value if value.nil?

        case value
        when Hash
          value.each_with_object({}) do |(key, val), memo|
            memo[key.to_s] = normalize_settings(val)
          end
        when Array
          value.map { |element| normalize_settings(element) }
        else
          value
        end
      end
    end
  end
end
