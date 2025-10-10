# FeedMonitor
Short description and motivation.

## Usage
How to use my plugin.

## Installation
Add this line to your application's Gemfile:

```ruby
gem "feed_monitor"
```

And then execute:
```bash
$ bundle
```

Mount the engine inside your host application's routes with the install generator:

```bash
$ bin/rails generate feed_monitor:install
```

By default the engine mounts at `/feed_monitor`. Provide a custom mount point with the `--mount-path` option:

```bash
$ bin/rails generate feed_monitor:install --mount-path=/admin/feeds
```

## Configuration

Feed Monitor exposes a lightweight configuration DSL so host applications can tune queue names, HTTP behaviour, scraper adapters, and retention defaults without monkey patches. The install generator drops `config/initializers/feed_monitor.rb` with commented defaults—update that file to match your environment:

```ruby
FeedMonitor.configure do |config|
  # Queue names and concurrency (Solid Queue by default)
  config.queue_namespace = "feed_monitor"
  config.fetch_queue_name = "#{config.queue_namespace}_fetch"
  config.fetch_queue_concurrency = 2

  # HTTP client defaults (Faraday)
  config.http.timeout = 15
  config.http.open_timeout = 5
  config.http.headers = { "X-Request-ID" => -> { SecureRandom.uuid } }
  config.http.retry_max = 6

  # Scraper adapters (inherit from FeedMonitor::Scrapers::Base)
  config.scrapers.register(:readability, FeedMonitor::Scrapers::Readability)
  # config.scrapers.register(:custom, "MyApp::Scrapers::Custom")

  # Retention defaults applied when a source leaves fields blank
  config.retention.items_retention_days = 30
  config.retention.max_items = nil
  config.retention.strategy = :soft_delete
end
```

HTTP settings feed directly into the Faraday client (timeouts, retry policy, default headers). Scraper registrations override the built-in constant lookup so you can swap the adapter per source name. Retention defaults act as fallbacks—sources can still override or clear them on a per-record basis.

Set `config.retention.items_retention_days` and `config.retention.max_items` to `nil` (or leave them unset) if you never want the engine to prune items by default. Individual sources can still opt into retention policies later via the admin UI.

## Retention Strategies

Feed Monitor now ships with per-source retention controls so historical data stays within the limits you set:

- **Retention window** – set `items_retention_days` (via the admin UI or `FeedMonitor::Source`) to automatically prune items older than the specified number of days.
- **Maximum stored items** – set `max_items` to keep only the newest N items for a source.

Both policies run immediately after each successful fetch. The engine destroys pruned items alongside their associated scraped content and logs, keeping counter caches accurate without any additional cron jobs. Leave either field blank when you want to retain items indefinitely.

Feed Monitor also ships with nightly maintenance jobs (`FeedMonitor::ItemCleanupJob` and `FeedMonitor::LogCleanupJob`) that you can trigger manually via `rake feed_monitor:cleanup:items` and `rake feed_monitor:cleanup:logs`, or schedule via Solid Queue recurring tasks. Pass `SOFT_DELETE=true` to soft delete items while reviewing, or override `FETCH_LOG_DAYS` / `SCRAPE_LOG_DAYS` to trim logs with custom windows.

## Contributing
Contribution directions go here.

## License
The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
