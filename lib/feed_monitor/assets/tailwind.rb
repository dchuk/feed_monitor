require "tailwindcss-rails"
require "tailwindcss/ruby"
require "tempfile"
require "fileutils"

module FeedMonitor
  module Assets
    module Tailwind
      class VerificationError < StandardError; end

      module_function

      def build!
        ensure_build_directory!
        run_tailwind!(output_path: build_path)
        build_path
      end

      def verify!
        ensure_build_directory!

        expected = rendered_css
        current = build_path.exist? ? build_path.read : ""

        return true if current == expected

        raise VerificationError,
          "FeedMonitor Tailwind build is out of date. Run `bin/rails app:feed_monitor:assets:build` to refresh app/assets/builds/tailwind.css before committing."
      end

      def rendered_css
        Dir.mktmpdir do |dir|
          tmp_path = Pathname(dir).join("tailwind.css")
          run_tailwind!(output_path: tmp_path)
          tmp_path.read
        end
      end

      def run_tailwind!(output_path:)
        command = [
          Tailwindcss::Ruby.executable,
          "-i", input_path.to_s,
          "-o", output_path.to_s
        ]

        env = { "BUNDLE_GEMFILE" => engine_gemfile.to_s }

        system(env, *command, chdir: engine_root.to_s, exception: true)
      end

      def ensure_build_directory!
        FileUtils.mkdir_p(build_path.dirname) unless build_path.dirname.exist?
      end

      def input_path
        engine_root.join("app/assets/tailwind/application.css")
      end

      def build_path
        engine_root.join("app/assets/builds/tailwind.css")
      end

      def engine_root
        FeedMonitor::Engine.root
      end

      def engine_gemfile
        engine_root.join("Gemfile")
      end
    end
  end
end
