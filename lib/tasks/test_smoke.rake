# frozen_string_literal: true

namespace :test do
  desc "Run fast FeedMonitor smoke tests (unit, jobs, and core helpers)"
  task :smoke do
    paths = %w[test/lib test/jobs test/helpers]
    env = { "FEED_MONITOR_TEST_WORKERS" => ENV.fetch("FEED_MONITOR_TEST_WORKERS", "1") }
    command = [ "rbenv", "exec", "bundle", "exec", "rails", "test", *paths ]

    sh env, *command
  end
end
