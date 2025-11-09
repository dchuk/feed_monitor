# frozen_string_literal: true

# Rails application template for spinning up a minimal SourceMonitor host.

source_paths.unshift(__dir__)

gem "source_monitor", path: File.expand_path("../..", __dir__)

environment <<~RUBY
  config.active_job.queue_adapter = :solid_queue
RUBY

after_bundle do
  rails_command "source_monitor:install"
  rails_command "railties:install:migrations FROM=source_monitor"
  rails_command "db:prepare"

  route %(root to: redirect("/source_monitor", status: 302))

  if File.exist?("Procfile.dev")
    append_to_file "Procfile.dev", <<~PROC

      worker: bin/rails solid_queue:start
      jobs: bin/jobs --recurring_schedule_file=config/recurring.yml
    PROC
  else
    file "Procfile.dev", <<~PROC
      web: bin/rails server
      worker: bin/rails solid_queue:start
      jobs: bin/jobs --recurring_schedule_file=config/recurring.yml
    PROC
  end

  append_to_file "db/seeds.rb", <<~RUBY

    SourceMonitor::Source.find_or_create_by!(feed_url: "https://weblog.rubyonrails.org/feed/") do |source|
      source.name = "Rails Blog"
      source.fetch_interval_hours = 1
      source.scraping_enabled = false
      source.auto_scrape = false
    end
  RUBY

  rails_command "db:seed"

  copy_file "README.md", "README.source_monitor.md"

  say <<~TEXT

    ✅ SourceMonitor basic host setup complete.
    Run `bin/dev` to start the web UI, Solid Queue worker, and recurring jobs.
    Visit http://localhost:3000/source_monitor after the first fetch finishes.
  TEXT
end
