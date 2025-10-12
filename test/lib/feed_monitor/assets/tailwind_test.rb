require "test_helper"

module FeedMonitor
  module Assets
    class TailwindTest < ActiveSupport::TestCase
      BUILD_PATH = FeedMonitor::Assets::Tailwind.send(:build_path)

      def setup
        @original_css = BUILD_PATH.read if BUILD_PATH.exist?
      end

      def teardown
        return unless defined?(@original_css)

        File.write(BUILD_PATH, @original_css) if @original_css
      end

      test "build! runs the Tailwind compiler for the engine" do
        captured = nil

        FeedMonitor::Assets::Tailwind.stub(:run_tailwind!, ->(output_path:) { captured = output_path }) do
          FeedMonitor::Assets::Tailwind.build!
        end

        assert_equal BUILD_PATH, captured
      end

      test "verify! passes when the compiled CSS matches" do
        css = "/* test css */"
        File.write(BUILD_PATH, css)

        FeedMonitor::Assets::Tailwind.stub(:rendered_css, css) do
          assert FeedMonitor::Assets::Tailwind.verify!
        end
      end

      test "verify! raises when the compiled CSS is stale" do
        File.write(BUILD_PATH, "/* stale css */")

        FeedMonitor::Assets::Tailwind.stub(:rendered_css, "/* fresh css */") do
          assert_raises FeedMonitor::Assets::Tailwind::VerificationError do
            FeedMonitor::Assets::Tailwind.verify!
          end
        end
      end
    end
  end
end
