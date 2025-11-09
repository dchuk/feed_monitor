# frozen_string_literal: true

require "test_helper"

module Feedmon
  module Scrapers
    class BaseTest < ActiveSupport::TestCase
      class FakeScraper < Base
        def self.default_settings
          {
            html_selector: "article",
            timeouts: {
              open: 1,
              read: 5
            }
          }
        end

        def call
          Result.new(
            status: :success,
            html: "<html></html>",
            content: "body",
            metadata: { settings: settings }
          )
        end
      end

      test "base class raises when #call is not implemented" do
        assert_raises(NotImplementedError) do
          Base.call(item: Feedmon::Item.new, source: Feedmon::Source.new)
        end
      end

      test "settings merge defaults, source overrides, and call overrides" do
        source = Feedmon::Source.new(
          scrape_settings: {
            html_selector: "main article",
            timeouts: { read: 10 },
            headers: { "User-Agent" => "Feedmon" }
          }
        )

        result = FakeScraper.call(
          item: Feedmon::Item.new,
          source: source,
          settings: { timeouts: { read: 2 }, headers: { "Accept" => "text/html" } }
        )

        merged_settings = result.metadata[:settings]

        assert_equal "main article", merged_settings[:html_selector]
        assert_equal 1, merged_settings[:timeouts][:open]
        assert_equal 2, merged_settings[:timeouts][:read]
        assert_equal "Feedmon", merged_settings[:headers]["User-Agent"]
        assert_equal "text/html", merged_settings[:headers][:Accept]
        assert_instance_of ActiveSupport::HashWithIndifferentAccess, merged_settings
      end

      test "adapter name infers from class" do
        assert_equal "fake", FakeScraper.adapter_name
      end

      test "result struct exposes keyword attributes" do
        result = Feedmon::Scrapers::Base::Result.new(status: :partial, html: nil, content: nil, metadata: {})

        assert_equal :partial, result.status
        assert_nil result.html
        assert_equal({}, result.metadata)
      end
    end
  end
end
