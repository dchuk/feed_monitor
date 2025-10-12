# frozen_string_literal: true

module FeedMonitor
  module Scraping
    class ItemScraper
      # Resolves scraper adapter classes based on configuration or engine namespace.
      class AdapterResolver
        VALID_NAME_PATTERN = /\A[a-z0-9_]+\z/i.freeze

        def initialize(name:, source:)
          @name = name.to_s
          @source = source
        end

        def resolve!
          raise_unknown!("No scraper adapter configured for source") if name.blank?
          raise_unknown!("Invalid scraper adapter: #{name}") unless VALID_NAME_PATTERN.match?(name)

          configured = FeedMonitor.config.scrapers.adapter_for(name)
          return configured if configured

          constant = resolve_constant
          return constant if constant <= FeedMonitor::Scrapers::Base

          raise_unknown!("Unknown scraper adapter: #{name}")
        rescue NameError
          raise_unknown!("Unknown scraper adapter: #{name}")
        end

        private

        attr_reader :name, :source

        def resolve_constant
          FeedMonitor::Scrapers.const_get(name.camelize)
        end

        def raise_unknown!(message)
          raise FeedMonitor::Scraping::ItemScraper::UnknownAdapterError, message
        end
      end
    end
  end
end

