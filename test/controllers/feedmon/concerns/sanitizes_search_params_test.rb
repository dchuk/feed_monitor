# frozen_string_literal: true

require "test_helper"

module Feedmon
  module Concerns
    class SanitizesSearchParamsTest < ActiveSupport::TestCase
      class DummyController
        include Feedmon::SanitizesSearchParams

        attr_reader :params

        def initialize(raw_params)
          @params = ActionController::Parameters.new(raw_params)
        end
      end

      test "removes blank values and sanitizes content" do
        controller = DummyController.new(
          q: {
            name_cont: " <script>alert(1)</script> ",
            blank_field: "   ",
            nil_field: nil
          }
        )

        result = controller.send(:sanitized_search_params)

        assert_equal({ "name_cont" => "alert(1)" }, result)
      end

      test "returns empty hash when params missing" do
        controller = DummyController.new({})

        result = controller.send(:sanitized_search_params)

        assert_equal({}, result)
      end

      test "records default sorts through searchable_with DSL" do
        assert_equal(
          [ "created_at desc" ],
          Feedmon::SourcesController._default_search_sorts
        )
        assert_equal(
          [ "published_at desc", "created_at desc" ],
          Feedmon::ItemsController._default_search_sorts
        )
      end
    end
  end
end
