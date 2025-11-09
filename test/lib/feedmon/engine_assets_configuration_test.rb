require "test_helper"
module Feedmon
  class EngineAssetsConfigurationTest < ActiveSupport::TestCase
    class FakeAssets
      attr_reader :paths, :precompile

      def initialize
        @paths = []
        @precompile = []
      end
    end

    class FakeConfig
      attr_reader :assets

      def initialize(assets:)
        @assets = assets
      end
    end

    class FakeApp
      attr_reader :config

      def initialize
        @config = FakeConfig.new(assets: FakeAssets.new)
      end
    end

    setup do
      @app = FakeApp.new
      @assets_initializer = Feedmon::Engine.initializers.find { |initializer| initializer.name == "feedmon.assets" }
      @sprockets_initializer = Feedmon::Engine.initializers.find { |initializer| initializer.name == "feedmon.assets.sprockets" }
      @images_root = Feedmon::Engine.root.join("app/assets/images/feedmon")
      @svgs_root = Feedmon::Engine.root.join("app/assets/svgs/feedmon")
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
        Feedmon::Engine.root.join("app/assets/builds"),
        Feedmon::Engine.root.join("app/assets/images"),
        Feedmon::Engine.root.join("app/assets/svgs")
      ].map(&:to_s)

      expected_paths.each do |path|
        assert_includes @app.config.assets.paths, path
      end
    end

    test "sprockets initializer adds namespaced asset files to precompile" do
      File.write(@images_root.join("test.png"), "fake-image")
      File.write(@svgs_root.join("test.svg"), "fake-svg")

      @sprockets_initializer.run(@app)

      assert_includes @app.config.assets.precompile, "feedmon/test.png"
      assert_includes @app.config.assets.precompile, "feedmon/test.svg"
    end
  end
end
