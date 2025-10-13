# frozen_string_literal: true

module FeedMonitor
  module Pagination
    Result = Struct.new(
      :records,
      :page,
      :per_page,
      :has_next_page,
      :has_previous_page,
      keyword_init: true
    ) do
      def has_next_page?
        !!has_next_page
      end

      def has_previous_page?
        !!has_previous_page
      end

      def next_page
        return nil unless has_next_page

        page + 1
      end

      def previous_page
        return nil unless has_previous_page

        [ page - 1, 1 ].max
      end
    end

    class Paginator
      DEFAULT_PER_PAGE = 25

      def initialize(scope:, page: 1, per_page: DEFAULT_PER_PAGE)
        @scope = scope
        @page = normalize_page(page)
        @per_page = normalize_per_page(per_page)
      end

      def paginate
        paginated_records = fetch_records
        has_next_page = paginated_records.length > per_page

        Result.new(
          records: paginated_records.first(per_page),
          page: page,
          per_page: per_page,
          has_next_page: has_next_page,
          has_previous_page: page > 1
        )
      end

      private

      attr_reader :scope, :page, :per_page

      def fetch_records
        offset = (page - 1) * per_page

        relation = scope.is_a?(ActiveRecord::Relation) ? scope : Array(scope)

        if relation.is_a?(Array)
          relation.slice(offset, per_page + 1) || []
        else
          relation.offset(offset).limit(per_page + 1).to_a
        end
      end

      def normalize_page(value)
        number = value.to_i
        number = 1 if number <= 0
        number
      rescue StandardError
        1
      end

      def normalize_per_page(value)
        number = value.to_i
        return DEFAULT_PER_PAGE if number <= 0

        [ number, 100 ].min
      rescue StandardError
        DEFAULT_PER_PAGE
      end
    end
  end
end
