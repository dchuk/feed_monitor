# frozen_string_literal: true

# Application template for a production-style Feedmon host.

source_paths.unshift(__dir__)

gem "feedmon", path: File.expand_path("../..", __dir__)
gem "mission_control-jobs", "~> 0.1"
gem "redis-client", "~> 0.22"

environment <<~RUBY
  config.active_job.queue_adapter = :solid_queue
RUBY

after_bundle do
  rails_command "feedmon:install", abort_on_failure: true
  rails_command "railties:install:migrations FROM=feedmon", abort_on_failure: true
  rails_command "db:prepare", abort_on_failure: true

  route <<~RUBY
    mount Feedmon::Engine => "/operations/feedmon"
    mount MissionControl::Jobs::Engine => "/mission_control"

    get "/feedmon/metrics", to: "FeedmonMetricsController#show"
    root to: redirect("/operations/feedmon", status: 302)
  RUBY

  copy_file "README.md", "README.feedmon.md"
  copy_file "files/app/controllers/feedmon_metrics_controller.rb", "app/controllers/feedmon_metrics_controller.rb", force: true
  copy_file "files/config/initializers/feedmon_instrumentation.rb", "config/initializers/feedmon_instrumentation.rb", force: true
  copy_file "files/config/solid_queue.yml", "config/solid_queue.yml", force: true

  create_file ".env.example", "" unless File.exist?(".env.example")

  append_to_file ".env.example", <<~ENV
    DATABASE_URL=postgres://postgres:postgres@localhost:5432/feedmon_advanced_development
    REDIS_URL=redis://localhost:6379/0
    FEEDMON_METRICS_USER=monitor
    FEEDMON_METRICS_PASS=monitor
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

  gsub_file "config/initializers/feedmon.rb",
    "config.mission_control_enabled = false",
    "config.mission_control_enabled = true"

  gsub_file "config/initializers/feedmon.rb",
    "config.mission_control_dashboard_path = nil",
    'config.mission_control_dashboard_path = "/mission_control"'

  gsub_file "config/initializers/feedmon.rb",
    "config.realtime.adapter = :solid_cable",
    "config.realtime.adapter = :redis\n  config.realtime.redis_url = ENV.fetch(\"REDIS_URL\")"

  gsub_file "config/initializers/feedmon.rb",
    "config.fetch_queue_concurrency = 2",
    "config.fetch_queue_concurrency = ENV.fetch(\"FEEDMON_FETCH_CONCURRENCY\", 4).to_i"

  gsub_file "config/initializers/feedmon.rb",
    "config.scrape_queue_concurrency = 2",
    "config.scrape_queue_concurrency = ENV.fetch(\"FEEDMON_SCRAPE_CONCURRENCY\", 2).to_i"

  append_to_file "db/seeds.rb", <<~RUBY

    Feedmon::Source.find_or_create_by!(feed_url: "https://news.ycombinator.com/rss") do |source|
      source.name = "Hacker News"
      source.fetch_interval_hours = 0.5
      source.scraping_enabled = true
      source.auto_scrape = true
      source.scrape_settings = { selectors: { content: "#hnmain" } }
    end
  RUBY

  rails_command "db:seed"

  say <<~TEXT

    ✅ Advanced Feedmon host ready.
    Configure REDIS_URL and FEEDMON_METRICS_* credentials before running `bin/dev`.
  TEXT
end
