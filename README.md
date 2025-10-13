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

  # Realtime transport (Action Cable)
  config.realtime.adapter = :solid_cable
  config.realtime.solid_cable.message_retention = "12.hours"
  # config.realtime.adapter = :redis
  # config.realtime.redis_url = ENV.fetch("REDIS_URL")

  # HTTP client defaults (Faraday)
  config.http.timeout = 15
  config.http.open_timeout = 5
  config.http.headers = { "X-Request-ID" => -> { SecureRandom.uuid } }
  config.http.retry_max = 6

  # Scraper adapters (inherit from FeedMonitor::Scrapers::Base)
  config.scrapers.register(:readability, FeedMonitor::Scrapers::Readability)
  # config.scrapers.register(:custom, "MyApp::Scrapers::Custom")

  # Retention defaults applied when a source leaves fields blank
  config.retention.items_retention_days = nil
  config.retention.max_items = nil
  config.retention.strategy = :soft_delete

  # Event callbacks and item processors (each handler receives an event object)
  config.events.after_item_created do |event|
    NewItemPublisher.publish(event.item, source: event.source)
  end

  config.events.after_fetch_completed do |event|
    Rails.logger.info("[FeedMonitor] #{event.source.name} fetch finished with #{event.status}")
  end

  config.events.register_item_processor ->(context) { SearchIndexer.index(context.item) }
end
```

HTTP settings feed directly into the Faraday client (timeouts, retry policy, default headers). Scraper registrations override the built-in constant lookup so you can swap the adapter per source name. Retention defaults act as fallbacks—leave them as `nil` to retain items indefinitely or set explicit values to opt every new source into pruning.

Feed Monitor ships with [Solid Cable](https://github.com/rails/solid_cable) enabled by default so Turbo Streams work without Redis. The engine creates the `solid_cable_messages` table through its migrations and configures Action Cable to use Solid Cable in every environment. Hosts that prefer Redis can flip `config.realtime.adapter = :redis` (and optionally `config.realtime.redis_url`) in the initializer and restart.

**Action Cable requirement**: Real-time UI updates require Action Cable base classes in your host application. If they don't already exist, create them:

```ruby
# app/channels/application_cable/connection.rb
module ApplicationCable
  class Connection < ActionCable::Connection::Base
  end
end

# app/channels/application_cable/channel.rb
module ApplicationCable
  class Channel < ActionCable::Channel::Base
  end
end
```

These are standard Rails boilerplate required by Action Cable. The engine will auto-configure the adapter and mount routes, but Rails expects these classes to exist in the host application.

The event layer lets host apps plug into the engine without monkey patches. Use `config.events.after_item_created`, `after_item_scraped`, and `after_fetch_completed` to react to new data or errors, and register lightweight item processors for denormalization or indexing. Each handler receives a structured event object so you can inspect the item, source, and status safely.

## Model Extensions

Feed Monitor models are now configurable so host apps can add behaviour without reopening engine classes:

- **Custom table prefixes** – `config.models.table_name_prefix` defaults to `feed_monitor_`. Override it (e.g. `"tenant_feed_monitor_"`) before running the engine migrations when you need bespoke naming or multi-tenant schemas.
- **Mix in concerns** – `config.models.source.include_concern "MyApp::FeedMonitor::SourceExtensions"` includes modules that add associations, scopes, or helpers. Concerns can hold reusable validation methods or callbacks.
- **Register validations** – attach validation methods or callables with `config.models.source.validate :ensure_metadata_rules` or `config.models.item.validate ->(record) { … }`. Blocks receive the record instance so you can reuse shared helpers.
- **Single Table Inheritance** – the `feed_monitor_sources` table now includes a `type` column, enabling subclasses like `FeedMonitor::SponsoredSource < FeedMonitor::Source`. Combine STI with per-type validations or background workflows through the configuration hooks above.

The dummy host app demonstrates these features by mixing in a concern that adds `testing_notes` metadata, validating the field length, and enforcing a minimum fetch cadence for `FeedMonitor::SponsoredSource` records.

## Retention Strategies

Feed Monitor now ships with per-source retention controls so historical data stays within the limits you set:

- **Retention window** – set `items_retention_days` (via the admin UI or `FeedMonitor::Source`) to automatically prune items older than the specified number of days.
- **Maximum stored items** – set `max_items` to keep only the newest N items for a source.

Both policies run immediately after each successful fetch. The engine destroys pruned items alongside their associated scraped content and logs, keeping counter caches accurate without any additional cron jobs. Leave either field blank when you want to retain items indefinitely.

Feed Monitor also ships with nightly maintenance jobs (`FeedMonitor::ItemCleanupJob` and `FeedMonitor::LogCleanupJob`) that you can trigger manually via `rake feed_monitor:cleanup:items` and `rake feed_monitor:cleanup:logs`, or schedule via Solid Queue recurring tasks. Pass `SOFT_DELETE=true` to soft delete items while reviewing, or override `FETCH_LOG_DAYS` / `SCRAPE_LOG_DAYS` to trim logs with custom windows.

## Development

Run `bin/setup` to install Ruby dependencies and prepare the dummy host application. Install frontend tooling once after cloning:

```bash
npm install
```

Quality checks mirror the CI pipeline:

- `bin/rubocop` (auto-correct with `bin/rubocop -A`)
- `bin/brakeman --no-pager`
- `bin/lint-assets`
- `bin/test-coverage` (wraps `bin/rails test` with SimpleCov gating)

## Contributing
Contribution directions go here.

## License
The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
