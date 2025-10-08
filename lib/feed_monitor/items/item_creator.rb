# frozen_string_literal: true

require "digest"
require "active_support/core_ext/object/blank"

module FeedMonitor
  module Items
    class ItemCreator
      FINGERPRINT_SEPARATOR = "\u0000".freeze
      CONTENT_METHODS = %i[content content_encoded summary].freeze
      TIMESTAMP_METHODS = %i[published updated].freeze

      def self.call(source:, entry:)
        new(source:, entry:).call
      end

      def initialize(source:, entry:)
        @source = source
        @entry = entry
      end

      def call
        attributes = build_attributes
        attributes[:guid] = attributes[:guid].presence || attributes[:content_fingerprint]

        source.items.create!(attributes)
      end

      private

      attr_reader :source, :entry

      def build_attributes
        url = extract_url
        title = string_or_nil(entry.title) if entry.respond_to?(:title)
        content = extract_content
        fingerprint = generate_fingerprint(title, url, content)

        {
          guid: extract_guid,
          title: title,
          url: url,
          canonical_url: url,
          summary: extract_summary,
          content: content,
          published_at: extract_timestamp,
          content_fingerprint: fingerprint
        }.compact
      end

      def extract_guid
        entry_guid = entry.respond_to?(:entry_id) ? string_or_nil(entry.entry_id) : nil
        return entry_guid if entry_guid.present?

        return unless entry.respond_to?(:id)

        entry_id = string_or_nil(entry.id)
        return if entry_id.blank?

        url = extract_url
        return entry_id if url.blank? || entry_id != url

        nil
      end

      def extract_url
        string_or_nil(entry.url) if entry.respond_to?(:url)
      end

      def extract_summary
        return unless entry.respond_to?(:summary)

        string_or_nil(entry.summary)
      end

      def extract_content
        CONTENT_METHODS.each do |method|
          next unless entry.respond_to?(method)

          value = string_or_nil(entry.public_send(method))
          return value if value.present?
        end
        nil
      end

      def extract_timestamp
        TIMESTAMP_METHODS.each do |method|
          next unless entry.respond_to?(method)

          value = entry.public_send(method)
          return value if value.present?
        end
        nil
      end

      def generate_fingerprint(title, url, content)
        Digest::SHA256.hexdigest(
          [
            title.to_s,
            url.to_s,
            content.to_s
          ].join(FINGERPRINT_SEPARATOR)
        )
      end

      def string_or_nil(value)
        return value unless value.is_a?(String)

        value.strip.presence
      end
    end
  end
end
