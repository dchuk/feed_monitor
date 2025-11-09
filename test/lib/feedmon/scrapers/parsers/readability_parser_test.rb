# frozen_string_literal: true

require "test_helper"

module Feedmon
  module Scrapers
    module Parsers
      class ReadabilityParserTest < ActiveSupport::TestCase
        setup do
          @html = file_fixture("articles/readability_sample.html").read
          @parser = ReadabilityParser.new
        end

        test "extracts content using selectors when provided" do
          result = @parser.parse(
            html: @html,
            selectors: { content: ".custom-body", title: ".headline" }
          )

          assert_equal :success, result.status
          assert_equal :selectors, result.strategy
          assert_includes result.content, "Custom selector text"
          assert_equal "Sample Article Title", result.title
        end

        test "falls back to readability extraction" do
          result = @parser.parse(html: @html)

          assert_equal :success, result.status
          assert_equal :readability, result.strategy
          assert_includes result.content, "Paragraph one introduces"
          assert_equal "Sample Article Title", result.title
          assert_kind_of Hash, result.metadata
        end

        test "returns partial when readability provides no content" do
          parser = Class.new(ReadabilityParser) do
            private

            def build_readability_document(*_args)
              Struct.new(:content, :title, :content_length).new(nil, nil, nil)
            end
          end.new

          result = parser.parse(html: "<html><body>nothing</body></html>")

          assert_equal :partial, result.status
          assert_nil result.content
        end
      end
    end
  end
end
