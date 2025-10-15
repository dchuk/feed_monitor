require "test_helper"
require "ostruct"

module FeedMonitor
  class EngineAssetsConfigurationTest < ActiveSupport::TestCase
    class FakeAssets
      attr_reader :paths, :precompile

      def initialize
        @paths = []
        @precompile = []
      end
    end

    class FakeApp
      attr_reader :config

      def initialize
        @config = OpenStruct.new(assets: FakeAssets.new)
      end
    end

    setup do
      @app = FakeApp.new
      @assets_initializer = FeedMonitor::Engine.initializers.find { |initializer| initializer.name == "feed_monitor.assets" }
      @sprockets_initializer = FeedMonitor::Engine.initializers.find { |initializer| initializer.name == "feed_monitor.assets.sprockets" }
      @images_root = FeedMonitor::Engine.root.join("app/assets/images/feed_monitor")
      @svgs_root = FeedMonitor::Engine.root.join("app/assets/svgs/feed_monitor")
      FileUtils.mkdir_p(@images_root)
      FileUtils.mkdir_p(@svgs_root)
    end

    teardown do
      FileUtils.rm_f(@images_root.join("test.png"))
      FileUtils.rm_f(@svgs_root.join("test.svg"))
    end

    test "assets initializer exposes build and media directories" do
      @assets_initializer.run(@app)

      expected_paths = [
        FeedMonitor::Engine.root.join("app/assets/builds"),
        FeedMonitor::Engine.root.join("app/assets/images"),
        FeedMonitor::Engine.root.join("app/assets/svgs")
      ].map(&:to_s)

      expected_paths.each do |path|
        assert_includes @app.config.assets.paths, path
      end
    end

    test "sprockets initializer adds namespaced asset files to precompile" do
      File.write(@images_root.join("test.png"), "fake-image")
      File.write(@svgs_root.join("test.svg"), "fake-svg")

      @sprockets_initializer.run(@app)

      assert_includes @app.config.assets.precompile, "feed_monitor/test.png"
      assert_includes @app.config.assets.precompile, "feed_monitor/test.svg"
    end
  end
end
