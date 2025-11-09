# frozen_string_literal: true

# Application template that registers the sample Markdown scraper adapter.

source_paths.unshift(__dir__)

gem "source_monitor", path: File.expand_path("../..", __dir__)

environment <<~RUBY
  config.active_job.queue_adapter = :solid_queue
RUBY

after_bundle do
  rails_command "source_monitor:install"
  rails_command "railties:install:migrations FROM=source_monitor"
  rails_command "db:prepare"

  route %(mount SourceMonitor::Engine => "/source_monitor")
  route %(root to: redirect("/source_monitor", status: 302))

  copy_file "README.md", "README.source_monitor.md"
  copy_file "lib/source_monitor/examples/scrapers/markdown_scraper.rb",
    "lib/source_monitor/examples/scrapers/markdown_scraper.rb"

  inject_into_file "config/initializers/source_monitor.rb",
    "\n  config.scrapers.register(:markdown, \"SourceMonitor::Examples::Scrapers::MarkdownScraper\")\n",
    after: "# config.scrapers.register(:custom, \"MyApp::Scrapers::CustomAdapter\")\n"

  append_to_file "db/seeds.rb", <<~RUBY

    SourceMonitor::Source.find_or_create_by!(feed_url: "https://buttondown.email/cassidoo/rss") do |source|
      source.name = "Cassidoo Newsletter"
      source.scraping_enabled = true
      source.auto_scrape = true
      source.scraper_adapter = "markdown"
      source.scrape_settings = { include_plain_text: true }
    end
  RUBY

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

  rails_command "db:seed"

  say <<~TEXT

    ✅ Custom adapter example ready. Fetch the seeded source and inspect scrape logs.
  TEXT
end
