require "feed_monitor/assets/bundler"

namespace :feed_monitor do
  namespace :assets do
    desc "Build Feed Monitor CSS and JS bundles"
    task build: :environment do
      FeedMonitor::Assets::Bundler.build!
    end

    desc "Verify required Feed Monitor asset bundles exist"
    task verify: :environment do
      FeedMonitor::Assets::Bundler.verify!
    end
  end
end

namespace :app do
  namespace :feed_monitor do
    namespace :assets do
      task build: "feed_monitor:assets:build"
      task verify: "feed_monitor:assets:verify"
    end
  end
end

if defined?(Rake::Task) && Rake::Task.task_defined?("test")
  Rake::Task["test"].enhance(["feed_monitor:assets:verify"])
end
