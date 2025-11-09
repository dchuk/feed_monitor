# frozen_string_literal: true

require "test_helper"
require "feedmon/scraping/item_scraper/adapter_resolver"

module Feedmon
  module Scraping
    class AdapterResolverTest < ActiveSupport::TestCase
      setup do
        Feedmon.reset_configuration!
      end

      teardown do
        Feedmon.reset_configuration!
      end

      test "resolves adapter registered via configuration" do
        Feedmon.configure do |config|
          config.scrapers.register(:custom, RegisteredAdapter)
        end

        resolver = Feedmon::Scraping::ItemScraper::AdapterResolver.new(name: "custom", source: build_source)

        assert_equal RegisteredAdapter, resolver.resolve!
      end

      test "resolves adapter class under Feedmon::Scrapers namespace" do
        resolver = Feedmon::Scraping::ItemScraper::AdapterResolver.new(name: "readability", source: build_source)

        assert_equal Feedmon::Scrapers::Readability, resolver.resolve!
      end

      test "raises when adapter name contains invalid characters" do
        resolver = Feedmon::Scraping::ItemScraper::AdapterResolver.new(name: "invalid-name!", source: build_source)

        assert_raises(Feedmon::Scraping::ItemScraper::UnknownAdapterError) { resolver.resolve! }
      end

      test "raises when adapter constant does not inherit from base class" do
        stub_const("Feedmon::Scrapers::Rogue", Class.new)

        resolver = Feedmon::Scraping::ItemScraper::AdapterResolver.new(name: "rogue", source: build_source)

        assert_raises(Feedmon::Scraping::ItemScraper::UnknownAdapterError) { resolver.resolve! }
      ensure
        Feedmon::Scrapers.send(:remove_const, :Rogue) if Feedmon::Scrapers.const_defined?(:Rogue)
      end

      test "raises when adapter cannot be resolved" do
        resolver = Feedmon::Scraping::ItemScraper::AdapterResolver.new(name: "missing", source: build_source)

        assert_raises(Feedmon::Scraping::ItemScraper::UnknownAdapterError) { resolver.resolve! }
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

      class RegisteredAdapter < Feedmon::Scrapers::Base
        def call
          Result.new(status: :success)
        end
      end
    end
  end
end
