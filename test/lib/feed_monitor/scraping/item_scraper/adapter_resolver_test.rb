# frozen_string_literal: true

require "test_helper"
require "feed_monitor/scraping/item_scraper/adapter_resolver"

module FeedMonitor
  module Scraping
    class AdapterResolverTest < ActiveSupport::TestCase
      setup do
        FeedMonitor.reset_configuration!
      end

      teardown do
        FeedMonitor.reset_configuration!
      end

      test "resolves adapter registered via configuration" do
        FeedMonitor.configure do |config|
          config.scrapers.register(:custom, RegisteredAdapter)
        end

        resolver = FeedMonitor::Scraping::ItemScraper::AdapterResolver.new(name: "custom", source: build_source)

        assert_equal RegisteredAdapter, resolver.resolve!
      end

      test "resolves adapter class under FeedMonitor::Scrapers namespace" do
        resolver = FeedMonitor::Scraping::ItemScraper::AdapterResolver.new(name: "readability", source: build_source)

        assert_equal FeedMonitor::Scrapers::Readability, resolver.resolve!
      end

      test "raises when adapter name contains invalid characters" do
        resolver = FeedMonitor::Scraping::ItemScraper::AdapterResolver.new(name: "invalid-name!", source: build_source)

        assert_raises(FeedMonitor::Scraping::ItemScraper::UnknownAdapterError) { resolver.resolve! }
      end

      test "raises when adapter constant does not inherit from base class" do
        stub_const("FeedMonitor::Scrapers::Rogue", Class.new)

        resolver = FeedMonitor::Scraping::ItemScraper::AdapterResolver.new(name: "rogue", source: build_source)

        assert_raises(FeedMonitor::Scraping::ItemScraper::UnknownAdapterError) { resolver.resolve! }
      ensure
        FeedMonitor::Scrapers.send(:remove_const, :Rogue) if FeedMonitor::Scrapers.const_defined?(:Rogue)
      end

      test "raises when adapter cannot be resolved" do
        resolver = FeedMonitor::Scraping::ItemScraper::AdapterResolver.new(name: "missing", source: build_source)

        assert_raises(FeedMonitor::Scraping::ItemScraper::UnknownAdapterError) { resolver.resolve! }
      end

      private

      def build_source
        create_source!(
          name: "Resolver Source",
          feed_url: "https://example.com/resolver.xml"
        )
      end

      def stub_const(name, value)
        names = name.split("::")
        constant_name = names.pop
        namespace = names.inject(Object) do |const, const_name|
          if const.const_defined?(const_name)
            const.const_get(const_name)
          else
            const.const_set(const_name, Module.new)
          end
        end
        namespace.const_set(constant_name, value)
      end

      class RegisteredAdapter < FeedMonitor::Scrapers::Base
        def call
          Result.new(status: :success)
        end
      end
    end
  end
end
