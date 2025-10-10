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

## Retention Strategies

Feed Monitor now ships with per-source retention controls so historical data stays within the limits you set:

- **Retention window** – set `items_retention_days` (via the admin UI or `FeedMonitor::Source`) to automatically prune items older than the specified number of days.
- **Maximum stored items** – set `max_items` to keep only the newest N items for a source.

Both policies run immediately after each successful fetch. The engine destroys pruned items alongside their associated scraped content and logs, keeping counter caches accurate without any additional cron jobs. Leave either field blank when you want to retain items indefinitely. Phase 10.02 will add dedicated cleanup jobs for scheduled maintenance runs when large datasets demand them.

## Contributing
Contribution directions go here.

## License
The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
