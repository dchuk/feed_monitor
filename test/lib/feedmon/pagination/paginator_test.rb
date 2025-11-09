# frozen_string_literal: true

require "test_helper"

module Feedmon
  module Pagination
    class PaginatorTest < ActiveSupport::TestCase
      setup do
        @source = create_source!
        @items = Array.new(6) do |index|
          Feedmon::Item.create!(
            source: @source,
            guid: SecureRandom.uuid,
            url: "https://example.com/articles/#{index}",
            title: "Item #{index}",
            published_at: Time.current - index.hours
          )
        end
      end

      test "paginates relation and reports presence of more records" do
        scope = Feedmon::Item.order(published_at: :desc)
        result = Feedmon::Pagination::Paginator.new(scope:, page: 1, per_page: 5).paginate

        assert_equal 5, result.records.size
        assert result.has_next_page?
        refute result.has_previous_page?
        assert_equal 1, result.page
      end

      test "handles out of range and coerces invalid page values" do
        scope = Feedmon::Item.order(published_at: :desc)

        result_page_zero = Feedmon::Pagination::Paginator.new(scope:, page: 0, per_page: 3).paginate
        assert_equal 1, result_page_zero.page
        assert_equal 3, result_page_zero.records.size

        result_page_three = Feedmon::Pagination::Paginator.new(scope:, page: 3, per_page: 3).paginate
        assert_equal 3, result_page_three.page
        assert_equal 0, result_page_three.records.size
        refute result_page_three.has_next_page?
        assert result_page_three.has_previous_page?
      end
    end
  end
end
