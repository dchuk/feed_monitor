# frozen_string_literal: true

require "test_helper"

module FeedMonitor
  class BasicTemplateTest < ActiveSupport::TestCase
    TEMPLATE_PATH = FeedMonitor::Engine.root.join("examples/basic_host/template.rb")

    test "template adds engine gem via relative path" do
      source = TEMPLATE_PATH.read

      assert_includes source, 'gem "feed_monitor", path: File.expand_path("../..", __dir__)',
        "expected basic template to reference the engine via a relative path"
    end

    test "template seeds demo source" do
      source = TEMPLATE_PATH.read

      assert_match(/FeedMonitor::Source\.find_or_create_by!/, source)
      assert_includes source, "Rails Blog"
    end
  end
end
