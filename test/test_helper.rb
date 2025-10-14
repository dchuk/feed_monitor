# Enable coverage reporting in CI or when explicitly requested.
if ENV["CI"] || ENV["COVERAGE"]
  require "simplecov"

  SimpleCov.start "rails" do
    enable_coverage :branch
    refuse_coverage_drop :line
    add_filter %r{^/test/}
  end

  SimpleCov.enable_for_subprocesses true
end

# Configure Rails Environment
ENV["RAILS_ENV"] = "test"

require_relative "../test/dummy/config/environment"
ActiveRecord::Migrator.migrations_paths = [ File.expand_path("../test/dummy/db/migrate", __dir__) ]
ActiveRecord::Migrator.migrations_paths << File.expand_path("../db/migrate", __dir__)
require "rails/test_help"
require "webmock/minitest"
require "vcr"
require "turbo-rails"
require "action_cable/test_helper"
require "turbo/broadcastable/test_helper"
require "securerandom"
require "minitest/mock"

require "capybara/rails"
require "capybara/minitest"

# Load fixtures from the engine
if ActiveSupport::TestCase.respond_to?(:fixture_paths=)
  fixtures_root = File.expand_path("fixtures", __dir__)
  ActiveSupport::TestCase.fixture_paths = [ fixtures_root ]
  ActionDispatch::IntegrationTest.fixture_paths = ActiveSupport::TestCase.fixture_paths
  ActiveSupport::TestCase.file_fixture_path = fixtures_root
  ActiveSupport::TestCase.fixtures :all
end

VCR.configure do |config|
  config.cassette_library_dir = File.expand_path("vcr_cassettes", __dir__)
  config.hook_into :webmock
  config.ignore_localhost = true
end

WebMock.disable_net_connect!(allow_localhost: true)

class ActiveSupport::TestCase
  setup do
    FeedMonitor.reset_configuration!
  end

  private

  def create_source!(attributes = {})
    defaults = {
      name: "Test Source",
      feed_url: "https://example.com/feed-#{SecureRandom.hex(4)}.xml",
      website_url: "https://example.com",
      fetch_interval_minutes: 60,
      scraper_adapter: "readability"
    }

    source = FeedMonitor::Source.new(defaults.merge(attributes))
    source.save!(validate: false)
    source
  end
end
