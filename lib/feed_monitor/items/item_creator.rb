# frozen_string_literal: true

require "digest"
require "json"
require "cgi"
require "active_support/core_ext/object/blank"
require "active_support/core_ext/time"
require "feed_monitor/instrumentation"
require "feed_monitor/scrapers/readability"

module FeedMonitor
  module Items
    class ItemCreator
      Result = Struct.new(:item, :status, :matched_by, keyword_init: true) do
        def created?
          status == :created
        end

        def updated?
          status == :updated
        end
      end
      FINGERPRINT_SEPARATOR = "\u0000".freeze
      CONTENT_METHODS = %i[content content_encoded summary].freeze
      TIMESTAMP_METHODS = %i[published updated].freeze
      KEYWORD_SEPARATORS = /[,;]+/.freeze
      METADATA_ROOT_KEY = "feedjira_entry".freeze
      def self.call(source:, entry:)
        new(source:, entry:).call
      end

      def initialize(source:, entry:)
        @source = source
        @entry = entry
      end

      def call
        attributes = build_attributes
        raw_guid = attributes[:guid]
        attributes[:guid] = raw_guid.presence || attributes[:content_fingerprint]

        existing_item, matched_by = existing_item_for(attributes, raw_guid_present: raw_guid.present?)

        if existing_item
          updated_item = update_existing_item(existing_item, attributes, matched_by)
          return Result.new(item: updated_item, status: :updated, matched_by: matched_by)
        end

        create_new_item(attributes, raw_guid_present: raw_guid.present?)
      end

      private

      attr_reader :source, :entry

      def existing_item_for(attributes, raw_guid_present:)
        guid = attributes[:guid]
        fingerprint = attributes[:content_fingerprint]

        if raw_guid_present
          existing = find_item_by_guid(guid)
          return [existing, :guid] if existing
        end

        if fingerprint.present?
          existing = find_item_by_fingerprint(fingerprint)
          return [existing, :fingerprint] if existing
        end

        [nil, nil]
      end

      def find_item_by_guid(guid)
        return if guid.blank?

        source.all_items.where("LOWER(guid) = ?", guid.downcase).first
      end

      def find_item_by_fingerprint(fingerprint)
        return if fingerprint.blank?

        source.all_items.find_by(content_fingerprint: fingerprint)
      end

      def instrument_duplicate(item, matched_by)
        return unless matched_by

        FeedMonitor::Instrumentation.item_duplicate(
          source_id: source.id,
          item_id: item.id,
          guid: item.guid,
          content_fingerprint: item.content_fingerprint,
          matched_by: matched_by
        )
      end

      def update_existing_item(existing_item, attributes, matched_by)
        apply_attributes(existing_item, attributes)
        existing_item.save!
        instrument_duplicate(existing_item, matched_by)
        existing_item
      end

      def create_new_item(attributes, raw_guid_present:)
        new_item = source.items.new
        apply_attributes(new_item, attributes)
        new_item.save!
        Result.new(item: new_item, status: :created)
      rescue ActiveRecord::RecordNotUnique
        handle_concurrent_duplicate(attributes, raw_guid_present:)
      end

      def handle_concurrent_duplicate(attributes, raw_guid_present:)
        matched_by = raw_guid_present ? :guid : :fingerprint
        existing = find_conflicting_item(attributes, matched_by)
        updated = update_existing_item(existing, attributes, matched_by)
        Result.new(item: updated, status: :updated, matched_by: matched_by)
      end

      def find_conflicting_item(attributes, matched_by)
        case matched_by
        when :guid
          find_item_by_guid(attributes[:guid]) || source.all_items.find_by!(guid: attributes[:guid])
        else
          fingerprint = attributes[:content_fingerprint]
          find_item_by_fingerprint(fingerprint) || source.all_items.find_by!(content_fingerprint: fingerprint)
        end
      end

      def apply_attributes(record, attributes)
        attributes = attributes.dup
        metadata = attributes.delete(:metadata)
        record.assign_attributes(attributes)
        record.metadata = metadata if metadata
      end

      def process_feed_content(raw_content, title:)
        return [raw_content, nil] unless should_process_feed_content?(raw_content)

        parser = feed_content_parser_class.new
        html = wrap_content_for_readability(raw_content, title: title)
        result = parser.parse(html: html, readability: default_feed_readability_options)

        processed_content = result.content.presence || raw_content
        metadata = build_feed_content_metadata(result: result, raw_content: raw_content, processed_content: processed_content)

        [processed_content, metadata.presence]
      rescue StandardError => error
        metadata = {
          "status" => "failed",
          "strategy" => "readability",
          "applied" => false,
          "changed" => false,
          "error_class" => error.class.name,
          "error_message" => error.message
        }
        [raw_content, metadata]
      end

      def should_process_feed_content?(raw_content)
        source.respond_to?(:feed_content_readability_enabled?) &&
          source.feed_content_readability_enabled? &&
          raw_content.present? &&
          html_fragment?(raw_content)
      end

      def feed_content_parser_class
        FeedMonitor::Scrapers::Parsers::ReadabilityParser
      end

      def wrap_content_for_readability(content, title:)
        safe_title = title.present? ? CGI.escapeHTML(title) : "Feed Entry"
        <<~HTML
          <!DOCTYPE html>
          <html>
            <head>
              <meta charset="utf-8">
              <title>#{safe_title}</title>
            </head>
            <body>
              #{content}
            </body>
          </html>
        HTML
      end

      def default_feed_readability_options
        default = FeedMonitor::Scrapers::Readability.default_settings[:readability]
        return {} unless default

        if default.respond_to?(:deep_dup)
          default.deep_dup
        else
          Marshal.load(Marshal.dump(default))
        end
      rescue TypeError
        default.dup
      end

      def build_feed_content_metadata(result:, raw_content:, processed_content:)
        metadata = {
          "strategy" => result.strategy&.to_s,
          "status" => result.status&.to_s,
          "applied" => result.content.present?,
          "changed" => processed_content != raw_content
        }

        if result.metadata && result.metadata[:readability_text_length]
          metadata["readability_text_length"] = result.metadata[:readability_text_length]
        end

        metadata["title"] = result.title if result.title.present?
        metadata.compact
      end

      def html_fragment?(value)
        value.to_s.match?(/<\s*\w+/)
      end

      def build_attributes
        url = extract_url
        title = string_or_nil(entry.title) if entry.respond_to?(:title)
        raw_content = extract_content
        content, content_processing_metadata = process_feed_content(raw_content, title: title)
        fingerprint = generate_fingerprint(title, url, content)
        published_at = extract_timestamp
        updated_at_source = extract_updated_timestamp

        metadata = extract_metadata
        if content_processing_metadata.present?
          metadata = metadata.merge("feed_content_processing" => content_processing_metadata)
        end

        {
          guid: extract_guid,
          title: title,
          url: url,
          canonical_url: url,
          author: extract_author,
          authors: extract_authors,
          summary: extract_summary,
          content: content,
          published_at: published_at,
          updated_at_source: updated_at_source,
          categories: extract_categories,
          tags: extract_tags,
          keywords: extract_keywords,
          enclosures: extract_enclosures,
          media_thumbnail_url: extract_media_thumbnail_url,
          media_content: extract_media_content,
          language: extract_language,
          copyright: extract_copyright,
          comments_url: extract_comments_url,
          comments_count: extract_comments_count,
          metadata: metadata,
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
        if entry.respond_to?(:url)
          primary_url = string_or_nil(entry.url)
          return primary_url if primary_url.present?
        end

        if entry.respond_to?(:link_nodes)
          alternate = Array(entry.link_nodes).find do |node|
            rel = string_or_nil(node&.rel)&.downcase
            rel.nil? || rel == "alternate"
          end
          alternate ||= Array(entry.link_nodes).first
          href = string_or_nil(alternate&.href)
          return href if href.present?
        end

        if entry.respond_to?(:links)
          href = Array(entry.links).map { |link| string_or_nil(link) }.find(&:present?)
          return href if href.present?
        end

        nil
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

      def extract_updated_timestamp
        return entry.updated if entry.respond_to?(:updated) && entry.updated.present?

        nil
      end

      def extract_author
        string_or_nil(entry.author) if entry.respond_to?(:author)
      end

      def extract_authors
        values = []

        if entry.respond_to?(:rss_authors)
          values.concat(Array(entry.rss_authors).map { |value| string_or_nil(value) })
        end

        if entry.respond_to?(:dc_creators)
          values.concat(Array(entry.dc_creators).map { |value| string_or_nil(value) })
        elsif entry.respond_to?(:dc_creator)
          values << string_or_nil(entry.dc_creator)
        end

        if entry.respond_to?(:author_nodes)
          values.concat(
            Array(entry.author_nodes).map do |node|
              next unless node.respond_to?(:name) || node.respond_to?(:email) || node.respond_to?(:uri)

              string_or_nil(node.name) || string_or_nil(node.email) || string_or_nil(node.uri)
            end
          )
        end

        if json_entry?
          if entry.respond_to?(:json) && entry.json
            json_authors = Array(entry.json["authors"]).map { |author| string_or_nil(author["name"]) }
            values.concat(json_authors)
            values << string_or_nil(entry.json.dig("author", "name"))
          end
        end

        primary_author = extract_author
        values << primary_author if primary_author.present?

        values.compact.uniq
      end

      def extract_categories
        list = []
        list.concat(Array(entry.categories)) if entry.respond_to?(:categories)
        list.concat(Array(entry.tags)) if entry.respond_to?(:tags)
        if json_entry? && entry.respond_to?(:json) && entry.json
          list.concat(Array(entry.json["tags"]))
        end
        sanitize_string_array(list)
      end

      def extract_tags
        tags = []

        tags.concat(Array(entry.tags)) if entry.respond_to?(:tags)

        if json_entry? && entry.respond_to?(:json) && entry.json
          tags.concat(Array(entry.json["tags"]))
        end

        tags = extract_categories if tags.empty? && entry.respond_to?(:categories)

        sanitize_string_array(tags)
      end

      def extract_keywords
        keywords = []
        keywords.concat(split_keywords(entry.media_keywords_raw)) if entry.respond_to?(:media_keywords_raw)
        keywords.concat(split_keywords(entry.itunes_keywords_raw)) if entry.respond_to?(:itunes_keywords_raw)
        sanitize_string_array(keywords)
      end

      def extract_enclosures
        enclosures = []

        if entry.respond_to?(:enclosure_nodes)
          Array(entry.enclosure_nodes).each do |node|
            url = string_or_nil(node&.url)
            next if url.blank?

            enclosures << {
              "url" => url,
              "type" => string_or_nil(node&.type),
              "length" => safe_integer(node&.length),
              "source" => "rss_enclosure"
            }.compact
          end
        end

        if atom_entry? && entry.respond_to?(:link_nodes)
          Array(entry.link_nodes).each do |link|
            next unless string_or_nil(link&.rel)&.downcase == "enclosure"

            url = string_or_nil(link&.href)
            next if url.blank?

            enclosures << {
              "url" => url,
              "type" => string_or_nil(link&.type),
              "length" => safe_integer(link&.length),
              "source" => "atom_link"
            }.compact
          end
        end

        if json_entry? && entry.respond_to?(:json) && entry.json
          Array(entry.json["attachments"]).each do |attachment|
            url = string_or_nil(attachment["url"])
            next if url.blank?

            enclosures << {
              "url" => url,
              "type" => string_or_nil(attachment["mime_type"]),
              "length" => safe_integer(attachment["size_in_bytes"]),
              "duration" => safe_integer(attachment["duration_in_seconds"]),
              "title" => string_or_nil(attachment["title"]),
              "source" => "json_feed_attachment"
            }.compact
          end
        end

        enclosures.uniq
      end

      def extract_media_thumbnail_url
        if entry.respond_to?(:media_thumbnail_nodes)
          thumbnail = Array(entry.media_thumbnail_nodes).find { |node| string_or_nil(node&.url).present? }
          return string_or_nil(thumbnail&.url) if thumbnail
        end

        string_or_nil(entry.image) if entry.respond_to?(:image)
      end

      def extract_media_content
        contents = []

        if entry.respond_to?(:media_content_nodes)
          Array(entry.media_content_nodes).each do |node|
            url = string_or_nil(node&.url)
            next if url.blank?

            contents << {
              "url" => url,
              "type" => string_or_nil(node&.type),
              "medium" => string_or_nil(node&.medium),
              "height" => safe_integer(node&.height),
              "width" => safe_integer(node&.width),
              "file_size" => safe_integer(node&.file_size),
              "duration" => safe_integer(node&.duration),
              "expression" => string_or_nil(node&.expression)
            }.compact
          end
        end

        contents.uniq
      end

      def extract_language
        if entry.respond_to?(:language)
          return string_or_nil(entry.language)
        end

        if json_entry? && entry.respond_to?(:json) && entry.json
          return string_or_nil(entry.json["language"])
        end

        nil
      end

      def extract_copyright
        if entry.respond_to?(:copyright)
          return string_or_nil(entry.copyright)
        end

        if json_entry? && entry.respond_to?(:json) && entry.json
          return string_or_nil(entry.json["copyright"])
        end

        nil
      end

      def extract_comments_url
        string_or_nil(entry.comments) if entry.respond_to?(:comments)
      end

      def extract_comments_count
        raw = nil
        raw ||= entry.slash_comments_raw if entry.respond_to?(:slash_comments_raw)
        raw ||= entry.comments_count if entry.respond_to?(:comments_count)
        safe_integer(raw)
      end

      def extract_metadata
        return {} unless entry.respond_to?(:to_h)

        normalized = normalize_metadata(entry.to_h)
        return {} if normalized.blank?

        { METADATA_ROOT_KEY => normalized }
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

      def sanitize_string_array(values)
        Array(values).map { |value| string_or_nil(value) }.compact.uniq
      end

      def split_keywords(value)
        return [] if value.nil?

        string = string_or_nil(value)
        return [] if string.blank?

        string.split(KEYWORD_SEPARATORS).map { |keyword| keyword.strip.presence }.compact
      end

      def safe_integer(value)
        return if value.nil?
        return value if value.is_a?(Integer)

        string = value.to_s.strip
        return if string.blank?

        Integer(string, 10)
      rescue ArgumentError
        nil
      end

      def json_entry?
        defined?(Feedjira::Parser::JSONFeedItem) && entry.is_a?(Feedjira::Parser::JSONFeedItem)
      end

      def atom_entry?
        defined?(Feedjira::Parser::AtomEntry) && entry.is_a?(Feedjira::Parser::AtomEntry)
      end

      def normalize_metadata(value)
        JSON.parse(JSON.generate(value))
      rescue JSON::GeneratorError, JSON::ParserError, TypeError
        {}
      end
    end
  end
end
