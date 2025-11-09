# frozen_string_literal: true

require "test_helper"

module Feedmon
  class SanitizesSearchParamsTest < ActionController::TestCase
    class TestController < ActionController::Base
      include Feedmon::SanitizesSearchParams

      searchable_with scope: -> { Feedmon::Source.all }, default_sorts: [ "created_at desc" ]

      def index
        @search_params = sanitized_search_params
        @q = build_search_query
        render plain: "ok"
      end
    end

    tests TestController

    setup do
      @routes = ActionDispatch::Routing::RouteSet.new
      @routes.draw do
        get "index" => "feedmon/sanitizes_search_params_test/test#index"
      end
      @controller.instance_variable_set(:@_routes, @routes)
    end

    test "build_search_query returns ransack query with default sorts" do
      get :index

      query = @controller.instance_variable_get(:@q)
      assert_not_nil query
      assert_equal 1, query.sorts.size
      assert_equal "created_at", query.sorts.first.name
      assert_equal "desc", query.sorts.first.dir
    end

    test "build_search_query preserves user-provided sorts" do
      get :index, params: { q: { s: "name asc" } }

      query = @controller.instance_variable_get(:@q)
      assert_not_nil query
      assert_equal 1, query.sorts.size
      assert_equal "name", query.sorts.first.name
      assert_equal "asc", query.sorts.first.dir
    end

    test "build_search_query uses sanitized search params" do
      get :index, params: { q: { name_cont: "test" } }

      search_params = @controller.instance_variable_get(:@search_params)
      assert_equal "test", search_params["name_cont"]
    end
  end
end
