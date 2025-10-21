# frozen_string_literal: true

require "test_helper"
require "fileutils"
require "bundler"
require "open3"
require "support/host_app_harness"
require "feed_monitor/version"

module FeedMonitor
  module Integration
    class ReleasePackagingTest < ActiveSupport::TestCase
      ENGINE_ROOT = File.expand_path("../..", __dir__)
      PKG_ROOT = File.join(ENGINE_ROOT, "pkg")
      UNPACK_ROOT = File.join(ENGINE_ROOT, "tmp/release_package")

      def setup
        super
        FileUtils.mkdir_p(PKG_ROOT)
        FileUtils.rm_rf(UNPACK_ROOT)
      end

      def teardown
        HostAppHarness.cleanup_working_directory
        FileUtils.rm_rf(UNPACK_ROOT)
        super
      end

      test "packaged gem installs and runs generator in host harness" do
        gem_path = build_gem!
        unpacked_path = unpack_gem!(gem_path)
        previous_override = ENV["FEED_MONITOR_GEM_PATH"]
        ENV["FEED_MONITOR_GEM_PATH"] = unpacked_path
        HostAppHarness.prepare_working_directory
        assert_equal File.expand_path(unpacked_path), HostAppHarness.send(:override_gem_path)

        HostAppHarness.bundle_exec!("rails", "g", "feed_monitor:install")
        migration_output = HostAppHarness.bundle_exec!("rails", "railties:install:migrations", "FROM=feed_monitor")
        assert_includes migration_output, "feed_monitor"

        output = HostAppHarness.bundle_exec!("rails", "runner", "puts FeedMonitor::Engine.isolated?")
        assert_equal "true\n", output
      ensure
        if previous_override
          ENV["FEED_MONITOR_GEM_PATH"] = previous_override
        else
          ENV.delete("FEED_MONITOR_GEM_PATH")
        end
      end

      private

      def build_gem!
        gem_path = File.join(PKG_ROOT, "feed_monitor-#{FeedMonitor::VERSION}.gem")
        FileUtils.rm_f(gem_path)

        env = {}
        env["RBENV_VERSION"] = HostAppHarness::TARGET_RUBY_VERSION if HostAppHarness.const_defined?(:TARGET_RUBY_VERSION)

        built_gem = File.join(ENGINE_ROOT, "feed_monitor-#{FeedMonitor::VERSION}.gem")
        FileUtils.rm_f(built_gem)

        output, status = Bundler.with_unbundled_env do
          Open3.capture2e(env, "rbenv", "exec", "gem", "build", "feed_monitor.gemspec", chdir: ENGINE_ROOT)
        end
        raise "Failed to build gem: #{output}" unless status.success?

        raise "Gem not found at #{built_gem}" unless File.exist?(built_gem)
        FileUtils.mkdir_p(PKG_ROOT)
        FileUtils.mv(built_gem, gem_path)

        gem_path
      end

      def unpack_gem!(gem_path)
        output, status = Bundler.with_unbundled_env do
          Open3.capture2e("gem", "unpack", gem_path, "--target", UNPACK_ROOT)
        end
        raise "Failed to unpack gem: #{output}" unless status.success?

        unpacked_path = Dir.glob(File.join(UNPACK_ROOT, "feed_monitor-*")).first
        raise "Expected unpacked gem directory under #{UNPACK_ROOT}" unless unpacked_path

        unpacked_path
      end
    end
  end
end
