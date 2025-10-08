# frozen_string_literal: true

require "test_helper"
require "fileutils"
require "rails/generators/test_case"
require "generators/feed_monitor/install/install_generator"

module FeedMonitor
  class InstallGeneratorTest < Rails::Generators::TestCase
    tests FeedMonitor::Generators::InstallGenerator
    destination File.expand_path("../tmp/install_generator", __dir__)

    def setup
      super
      prepare_destination
      write_routes_file
    end

    def test_generator_class_exists
      assert_kind_of Class, FeedMonitor::Generators::InstallGenerator
    end

    def test_mounts_engine_with_default_path
      run_generator
      assert_file "config/routes.rb", /mount FeedMonitor::Engine, at: "\/feed_monitor"/
    end

    def test_mounts_engine_with_custom_path
      run_generator ["--mount-path=/reader"]
      assert_file "config/routes.rb", /mount FeedMonitor::Engine, at: "\/reader"/
    end

    def test_mount_path_without_leading_slash_is_normalized
      run_generator ["--mount-path=admin/feed_monitor"]
      assert_file "config/routes.rb", /mount FeedMonitor::Engine, at: "\/admin\/feed_monitor"/
    end

    private

    def write_routes_file
      routes_path = File.join(destination_root, "config")
      FileUtils.mkdir_p(routes_path)
      File.write(File.join(routes_path, "routes.rb"), <<~RUBY)
        Rails.application.routes.draw do
        end
      RUBY
    end
  end
end
