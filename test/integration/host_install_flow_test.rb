# frozen_string_literal: true

require "test_helper"
require "support/host_app_harness"

module FeedMonitor
  module Integration
    class HostInstallFlowTest < ActiveSupport::TestCase
      SNAPSHOT_FILES = %w[
        config/application.rb
        config/cable.yml
        config/environments/development.rb
        config/environments/production.rb
        config/environments/test.rb
      ].freeze

      def setup
        super
        HostAppHarness.prepare_working_directory
      end

      def teardown
        HostAppHarness.cleanup_working_directory
        super
      end

      test "install generator integrates cleanly into host app" do
        HostAppHarness.bundle_exec!("rails", "g", "feed_monitor:install")

        assert HostAppHarness.exist?("config/initializers/feed_monitor.rb"), "initializer was not created"

        routes_contents = HostAppHarness.read("config/routes.rb")
        assert_includes routes_contents, "mount FeedMonitor::Engine, at: \"/feed_monitor\""
      end

      test "install generator preserves host configuration files" do
        baseline_digests = HostAppHarness.digest_files(SNAPSHOT_FILES)

        HostAppHarness.bundle_exec!("rails", "g", "feed_monitor:install")

        SNAPSHOT_FILES.each do |relative_path|
          assert_equal baseline_digests[relative_path], HostAppHarness.digest(relative_path), "Expected #{relative_path} to remain unchanged"
        end
      end
    end
  end
end
