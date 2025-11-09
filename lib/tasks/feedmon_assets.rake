require "feedmon/assets/bundler"

namespace :feedmon do
  namespace :assets do
    desc "Build Feedmon CSS and JS bundles"
    task build: :environment do
      Feedmon::Assets::Bundler.build!
    end

    desc "Verify required Feedmon asset bundles exist"
    task verify: :environment do
      Feedmon::Assets::Bundler.verify!
    end
  end
end

namespace :app do
  namespace :feedmon do
    namespace :assets do
      task build: "feedmon:assets:build"
      task verify: "feedmon:assets:verify"
    end
  end
end

if defined?(Rake::Task) && Rake::Task.task_defined?("test")
  Rake::Task["test"].enhance([ "feedmon:assets:verify" ])
end
