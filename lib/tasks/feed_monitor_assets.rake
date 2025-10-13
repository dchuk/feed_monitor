namespace :feed_monitor do
  namespace :assets do
    desc "Build Feed Monitor Tailwind CSS"
    task build: :environment do
      FeedMonitor::Assets::Tailwind.build!
    end

    desc "Verify Feed Monitor Tailwind CSS matches the generated output"
    task verify: :environment do
      FeedMonitor::Assets::Tailwind.verify!
    end
  end
end

if defined?(Rake::Task) && Rake::Task.task_defined?("test")
  Rake::Task["test"].enhance([ "feed_monitor:assets:verify" ])
end
