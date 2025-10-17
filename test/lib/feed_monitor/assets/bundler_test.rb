require "test_helper"
require "tmpdir"

module FeedMonitor
  module Assets
    class BundlerTest < ActiveSupport::TestCase
      setup do
        @tmp_dir = Pathname.new(Dir.mktmpdir("feed_monitor-assets"))
        @css_path = @tmp_dir.join("application.css")
        @js_path = @tmp_dir.join("application.js")
      end

      teardown do
        FileUtils.remove_entry(@tmp_dir) if @tmp_dir&.exist?
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

        FeedMonitor::Assets::Bundler.stub(:run_script!, ->(script, watch: false) { captured = [script, watch] }) do
          FeedMonitor::Assets::Bundler.build_css!
        end

        assert_equal ["build:css", false], captured
      end

      test "build_js! delegates to npm build:js" do
        captured = nil

        FeedMonitor::Assets::Bundler.stub(:run_script!, ->(script, watch: false) { captured = [script, watch] }) do
          FeedMonitor::Assets::Bundler.build_js!
        end

        assert_equal ["build:js", false], captured
      end

      test "verify! raises when a build artifact is missing" do
        FileUtils.rm_f(@css_path)
        File.write(@js_path, "// built js")

        error = nil
        FeedMonitor::Assets::Bundler.stub(:build_artifacts, [@css_path, @js_path]) do
          error = assert_raises FeedMonitor::Assets::Bundler::MissingBuildError do
            FeedMonitor::Assets::Bundler.verify!
          end
        end

        assert_match "application.css", error.message
      end

      test "verify! passes when both CSS and JS artifacts exist" do
        File.write(@css_path, "/* built css */")
        File.write(@js_path, "// built js")

        result = nil
        FeedMonitor::Assets::Bundler.stub(:build_artifacts, [@css_path, @js_path]) do
          result = FeedMonitor::Assets::Bundler.verify!
        end

        assert result
      end
    end
  end
end
