require "test_helper"

module FeedMonitor
  module Assets
    class BundlerTest < ActiveSupport::TestCase
      BUILD_ROOT = FeedMonitor::Engine.root.join("app/assets/builds/feed_monitor")

      setup do
        FileUtils.mkdir_p(BUILD_ROOT)
        @css_path = BUILD_ROOT.join("application.css")
        @js_path = BUILD_ROOT.join("application.js")
      end

      teardown do
        FileUtils.rm_f(@css_path)
        FileUtils.rm_f(@js_path)
      end

      test "build! runs npm build in the engine root" do
        captured = {}

        FeedMonitor::Assets::Bundler.stub(:run_script!, ->(script, watch: false) {
          captured[:script] = script
          captured[:watch] = watch
        }) do
          FeedMonitor::Assets::Bundler.build!
        end

        assert_equal "build", captured[:script]
        assert_not captured[:watch]
      end

      test "build_css! delegates to npm build:css" do
        captured = nil

        FeedMonitor::Assets::Bundler.stub(:run_script!, ->(script, watch: false) { captured = [ script, watch ] }) do
          FeedMonitor::Assets::Bundler.build_css!
        end

        assert_equal [ "build:css", false ], captured
      end

      test "build_js! delegates to npm build:js" do
        captured = nil

        FeedMonitor::Assets::Bundler.stub(:run_script!, ->(script, watch: false) { captured = [ script, watch ] }) do
          FeedMonitor::Assets::Bundler.build_js!
        end

        assert_equal [ "build:js", false ], captured
      end

      test "verify! raises when a build artifact is missing" do
        FileUtils.rm_f(@css_path)
        File.write(@js_path, "// built js")

        error = assert_raises FeedMonitor::Assets::Bundler::MissingBuildError do
          FeedMonitor::Assets::Bundler.verify!
        end

        assert_match "application.css", error.message
      end

      test "verify! passes when both CSS and JS artifacts exist" do
        File.write(@css_path, "/* built css */")
        File.write(@js_path, "// built js")

        assert FeedMonitor::Assets::Bundler.verify!
      end
    end
  end
end
