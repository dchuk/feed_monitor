# frozen_string_literal: true

require "readability"
require "nokolexbor"
require "active_support/core_ext/object/blank"

module FeedMonitor
  module Scrapers
    module Parsers
      class ReadabilityParser
        Result = Struct.new(:status, :content, :strategy, :title, :metadata, keyword_init: true)

        def parse(html:, selectors: nil, readability: nil)
          document = ::Nokolexbor::HTML(html)
          selectors_hash = normalize_hash(selectors)
          readability_options = normalize_hash(readability)

          content_html = extract_with_selectors(document, selectors_hash[:content])
          strategy = content_html.present? ? :selectors : :readability

          readability_doc = build_readability_document(html, readability_options)
          content_html = readability_doc.content&.strip if content_html.blank?

          status = content_html.present? ? :success : :partial

          title = extract_title(document, selectors_hash[:title], readability_doc)
          metadata = {}
          if readability_doc.respond_to?(:content_length)
            metadata[:readability_text_length] = readability_doc.content_length
          end

          Result.new(
            status: status,
            content: content_html.presence,
            strategy: strategy,
            title: title,
            metadata: metadata.compact
          )
        rescue StandardError => error
          Result.new(
            status: :failed,
            content: nil,
            strategy: :readability,
            title: nil,
            metadata: { error: error.class.name, message: error.message }
          )
        end

        private

        def normalize_hash(value)
          return {} unless value

          hash = value.respond_to?(:to_h) ? value.to_h : value
          hash.each_with_object({}) do |(key, val), memo|
            memo[key.to_sym] = val
          end
        end

        def extract_with_selectors(document, selectors)
          fragments = Array(selectors).filter_map do |selector|
            next if selector.blank?

            nodes = document.css(selector.to_s)
            next if nodes.empty?

            nodes.map(&:to_html).join("\n")
          end

          return if fragments.empty?

          fragments.join("\n")
        end

        def build_readability_document(html, options)
          symbolized = options.each_with_object({}) do |(key, value), memo|
            memo[key.to_sym] = value
          end

          ::Readability::Document.new(html, symbolized)
        end

        def extract_title(document, selectors, readability_doc)
          Array(selectors).each do |selector|
            next if selector.blank?

            node = document.at_css(selector.to_s)
            return node.text.strip if node&.text.present?
          end

          if readability_doc.respond_to?(:title)
            title = readability_doc.title&.strip
            return title if title.present?
          end

          document.at_css("title")&.text&.strip
        end
      end
    end
  end
end
