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
      run_generator [ "--mount-path=/reader" ]
      assert_file "config/routes.rb", /mount FeedMonitor::Engine, at: "\/reader"/
    end

    def test_mount_path_without_leading_slash_is_normalized
      run_generator [ "--mount-path=admin/feed_monitor" ]
      assert_file "config/routes.rb", /mount FeedMonitor::Engine, at: "\/admin\/feed_monitor"/
    end

    def test_creates_initializer_with_commented_defaults
      run_generator

      assert_file "config/initializers/feed_monitor.rb" do |content|
        assert_match(/FeedMonitor.configure do \|config\|/, content)
        assert_match(/config.queue_namespace = "feed_monitor"/, content)
        assert_match(/config.fetch_queue_name = "\#\{config.queue_namespace\}_fetch"/, content)
        assert_match(/config.scrape_queue_name = "\#\{config.queue_namespace\}_scrape"/, content)
        assert_match(/config.fetch_queue_concurrency = 2/, content)
        assert_match(/config.scrape_queue_concurrency = 2/, content)
        assert_match(/config.job_metrics_enabled = true/, content)
        assert_match(/config.mission_control_enabled = false/, content)
        assert_match(/config.mission_control_dashboard_path = nil/, content)
        assert_match(/config.health.window_size = 20/, content)
        assert_match(/config.health.auto_pause_threshold = 0.2/, content)
        assert_match(/config\.scraping\.max_in_flight_per_source/, content)
        assert_match(/config\.scraping\.max_bulk_batch_size/, content)
      end
    end

    def test_does_not_overwrite_existing_initializer
      initializer_path = File.join(destination_root, "config/initializers")
      FileUtils.mkdir_p(initializer_path)
      File.write(File.join(initializer_path, "feed_monitor.rb"), "# existing")

      run_generator

      assert_file "config/initializers/feed_monitor.rb", /# existing/
    end

    def test_does_not_duplicate_routes_when_rerun
      run_generator
      run_generator

      routes_contents = File.read(File.join(destination_root, "config/routes.rb"))
      assert_equal 1, routes_contents.scan(/mount FeedMonitor::Engine/).count
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
