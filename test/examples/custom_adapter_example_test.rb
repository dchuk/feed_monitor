# frozen_string_literal: true

require "test_helper"
require Feedmon::Engine.root.join("examples/custom_adapter/lib/feedmon/examples/scrapers/markdown_scraper.rb")

module Feedmon
  module Examples
    class CustomAdapterExampleTest < ActiveSupport::TestCase
      ItemStub = Struct.new(:content, :scraped_content, :summary, keyword_init: true)
      SourceStub = Struct.new(:scrape_settings, keyword_init: true)

      test "markdown scraper renders html and plain text" do
        item = ItemStub.new(content: "# Hello\n\nThis is **bold** markdown.")
        source = SourceStub.new(scrape_settings: { include_plain_text: true })

        result = Scrapers::MarkdownScraper.call(item: item, source: source)

        assert_equal :success, result.status
        assert_includes result.html, "<strong>bold</strong>"
        assert_equal "Hello\nThis is bold markdown.", result.content
        assert_equal Scrapers::MarkdownScraper.adapter_name, result.metadata[:adapter]
      end

      test "adapter handles override settings" do
        item = ItemStub.new(content: "plain body")
        source = SourceStub.new(scrape_settings: { include_plain_text: false })

        result = Scrapers::MarkdownScraper.call(item: item, source: source, settings: { wrap_in_article: false })

        assert_equal :success, result.status
        refute_includes result.html, "<article"
        assert_equal result.html, result.content, "expected plain text to mirror html when include_plain_text is false"
      end
    end
  end
end
