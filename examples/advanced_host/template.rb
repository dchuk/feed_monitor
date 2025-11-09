# frozen_string_literal: true

# Application template for a production-style SourceMonitor host.

source_paths.unshift(__dir__)

gem "source_monitor", path: File.expand_path("../..", __dir__)
gem "mission_control-jobs", "~> 0.1"
gem "redis-client", "~> 0.22"

environment <<~RUBY
  config.active_job.queue_adapter = :solid_queue
RUBY

after_bundle do
  rails_command "source_monitor:install", abort_on_failure: true
  rails_command "railties:install:migrations FROM=source_monitor", abort_on_failure: true
  rails_command "db:prepare", abort_on_failure: true

  route <<~RUBY
    mount SourceMonitor::Engine => "/operations/source_monitor"
    mount MissionControl::Jobs::Engine => "/mission_control"

    get "/source_monitor/metrics", to: "SourceMonitorMetricsController#show"
    root to: redirect("/operations/source_monitor", status: 302)
  RUBY

  copy_file "README.md", "README.source_monitor.md"
  copy_file "files/app/controllers/source_monitor_metrics_controller.rb", "app/controllers/source_monitor_metrics_controller.rb", force: true
  copy_file "files/config/initializers/source_monitor_instrumentation.rb", "config/initializers/source_monitor_instrumentation.rb", force: true
  copy_file "files/config/solid_queue.yml", "config/solid_queue.yml", force: true

  create_file ".env.example", "" unless File.exist?(".env.example")

  append_to_file ".env.example", <<~ENV
    DATABASE_URL=postgres://postgres:postgres@localhost:5432/sourcemon_advanced_development
    REDIS_URL=redis://localhost:6379/0
    SOURCE_MONITOR_METRICS_USER=monitor
    SOURCE_MONITOR_METRICS_PASS=monitor
  ENV

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

  gsub_file "config/initializers/source_monitor.rb",
    "config.mission_control_enabled = false",
    "config.mission_control_enabled = true"

  gsub_file "config/initializers/source_monitor.rb",
    "config.mission_control_dashboard_path = nil",
    'config.mission_control_dashboard_path = "/mission_control"'

  gsub_file "config/initializers/source_monitor.rb",
    "config.realtime.adapter = :solid_cable",
    "config.realtime.adapter = :redis\n  config.realtime.redis_url = ENV.fetch(\"REDIS_URL\")"

  gsub_file "config/initializers/source_monitor.rb",
    "config.fetch_queue_concurrency = 2",
    "config.fetch_queue_concurrency = ENV.fetch(\"SOURCE_MONITOR_FETCH_CONCURRENCY\", 4).to_i"

  gsub_file "config/initializers/source_monitor.rb",
    "config.scrape_queue_concurrency = 2",
    "config.scrape_queue_concurrency = ENV.fetch(\"SOURCE_MONITOR_SCRAPE_CONCURRENCY\", 2).to_i"

  append_to_file "db/seeds.rb", <<~RUBY

    SourceMonitor::Source.find_or_create_by!(feed_url: "https://news.ycombinator.com/rss") do |source|
      source.name = "Hacker News"
      source.fetch_interval_hours = 0.5
      source.scraping_enabled = true
      source.auto_scrape = true
      source.scrape_settings = { selectors: { content: "#hnmain" } }
    end
  RUBY

  rails_command "db:seed"

  say <<~TEXT

    ✅ Advanced SourceMonitor host ready.
    Configure REDIS_URL and SOURCE_MONITOR_METRICS_* credentials before running `bin/dev`.
  TEXT
end
