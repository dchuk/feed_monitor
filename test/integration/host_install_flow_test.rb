# frozen_string_literal: true

require "test_helper"
require "fileutils"
require "support/host_app_harness"

module Feedmon
  module Integration
    class HostInstallFlowTest < ActiveSupport::TestCase
      parallelize(workers: 1)

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
      HostAppHarness.bundle_exec!("rails", "g", "feedmon:install")

      assert HostAppHarness.exist?("config/initializers/feedmon.rb"), "initializer was not created"

      routes_contents = HostAppHarness.read("config/routes.rb")
      assert_includes routes_contents, "mount Feedmon::Engine, at: \"/feedmon\""
    end

    test "install generator is idempotent" do
      HostAppHarness.bundle_exec!("rails", "g", "feedmon:install")
      initializer_snapshot = HostAppHarness.read("config/initializers/feedmon.rb")

      HostAppHarness.bundle_exec!("rails", "g", "feedmon:install")

      routes_contents = HostAppHarness.read("config/routes.rb")
      assert_equal 1, routes_contents.scan(/mount Feedmon::Engine/).count
      assert_equal initializer_snapshot, HostAppHarness.read("config/initializers/feedmon.rb")
    end

    test "install generator preserves host configuration files" do
      baseline_digests = HostAppHarness.digest_files(SNAPSHOT_FILES)

      original_redis_url = ENV.delete("REDIS_URL")
      ENV["REDIS_URL"] = "redis://localhost:6379/1"
      HostAppHarness.bundle_exec!("rails", "g", "feedmon:install", env: { "REDIS_URL" => "redis://localhost:6379/1" })
    ensure
      if original_redis_url
        ENV["REDIS_URL"] = original_redis_url
      else
        ENV.delete("REDIS_URL")
      end

      SNAPSHOT_FILES.each do |relative_path|
        assert_equal baseline_digests[relative_path], HostAppHarness.digest(relative_path), "Expected #{relative_path} to remain unchanged"
      end
    end

    test "install generator skips existing initializer" do
      HostAppHarness.prepare_working_directory do |root|
        initializer_path = File.join(root, "config/initializers")
        FileUtils.mkdir_p(initializer_path)
        File.write(File.join(initializer_path, "feedmon.rb"), "# existing initializer")
      end

      HostAppHarness.bundle_exec!("rails", "g", "feedmon:install")

      content = HostAppHarness.read("config/initializers/feedmon.rb")
      assert_equal "# existing initializer", content.strip
    end

    test "engine respects existing queue adapter overrides" do
      HostAppHarness.prepare_working_directory do |root|
        application_rb = File.join(root, "config/application.rb")
        contents = File.read(application_rb)
        marker = "class Application < Rails::Application"
        replacement = <<~RUBY.chomp
          class Application < Rails::Application
            config.active_job.queue_adapter = :inline
        RUBY
        contents.sub!(marker, replacement)
        File.write(application_rb, contents)
      end

      HostAppHarness.bundle_exec!("rails", "g", "feedmon:install")
      output = HostAppHarness.bundle_exec!("rails", "runner", "puts ActiveJob::Base.queue_adapter_name")

      assert_match(/inline/, output)
    end

    test "install generator supports API only hosts" do
      HostAppHarness.prepare_working_directory(template: :api)

      HostAppHarness.bundle_exec!("rails", "g", "feedmon:install")

      routes_contents = HostAppHarness.read("config/routes.rb")
      assert_includes routes_contents, "mount Feedmon::Engine"
    end

    test "install generator preserves custom queue configuration" do
      HostAppHarness.prepare_working_directory do |root|
        queue_config = File.join(root, "config/queue.yml")
        content = File.read(queue_config)
        File.write(queue_config, "custom_queue_config: true\n" + content)
      end

      HostAppHarness.bundle_exec!("rails", "g", "feedmon:install")

      assert_match(/custom_queue_config: true/, HostAppHarness.read("config/queue.yml"))
    end

    test "install generator preserves redis action cable configuration" do
      HostAppHarness.prepare_working_directory do |root|
        cable_path = File.join(root, "config/cable.yml")
        File.write(cable_path, <<~YAML)
          development:
            adapter: redis
            url: redis://localhost:6379/1
          test:
            adapter: redis
            url: redis://localhost:6379/2
          production:
            adapter: redis
            url: <%= ENV.fetch("REDIS_URL", "redis://localhost:6379/3") %>
        YAML
      end

      HostAppHarness.bundle_exec!("rails", "g", "feedmon:install")

      cable_contents = HostAppHarness.read("config/cable.yml")
      assert_match(/adapter: redis/, cable_contents)
    end
    end
  end
end
