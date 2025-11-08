# Changelog

## Release Checklist

1. `rbenv exec bundle exec rails test`
2. `rbenv exec bundle exec rubocop`
3. `rbenv exec bundle exec rake app:feed_monitor:assets:verify`
4. `rbenv exec bundle exec gem build feed_monitor.gemspec`
5. Update release notes in this file and tag the release (`git tag vX.Y.Z`)
6. Push tags and publish the gem (`rbenv exec gem push pkg/feed_monitor-X.Y.Z.gem`)

## 0.1.0 - 2025-11-08

- First public release of the Feed Monitor engine with end-to-end feed ingest, scrape orchestration, and Solid Queue dashboards for monitoring, retries, and manual remediation.
- Includes Feedjira-based fetch pipeline with structured error handling, retention pruning, and configurable HTTP/Scraper adapters.
- Ships Solid Queue/Solid Cable defaults, Mission Control dashboard hooks, and CRUD UI for sources, items, and scraping state via the dummy host app.
- Provides install generator, initializer template, cleanup jobs, recurring schedules, and Readability-based scraping adapter to unlock full-content extraction out of the box.

### Upgrade Notes

1. Add `gem "feed_monitor", "~> 0.1.0"` to your host `Gemfile` and run `rbenv exec bundle install`.
2. Execute `rbenv exec bin/rails railties:install:migrations FROM=feed_monitor` followed by `rbenv exec bin/rails db:migrate` to copy and run Solid Queue + Feed Monitor migrations.
3. Review `config/initializers/feed_monitor.rb` for queue, scraping, and Mission Control settings; adjust the generated defaults to fit your environment.
4. If you surface Mission Control Jobs from the dashboard, ensure `mission_control-jobs` stays mounted and `config.mission_control_dashboard_path` is reachable.
5. Restart Solid Queue workers, Action Cable (Solid Cable by default), and any recurring job runners to pick up the new engine version.

## 2025-10-14

- Converted source fetch, retry, and bulk scrape member actions into nested resources. New controller endpoints:
  - `POST /feed_monitor/sources/:source_id/fetch` (`FeedMonitor::SourceFetchesController#create`)
  - `POST /feed_monitor/sources/:source_id/retry` (`FeedMonitor::SourceRetriesController#create`)
  - `POST /feed_monitor/sources/:source_id/bulk_scrape` (`FeedMonitor::SourceBulkScrapesController#create`)
  Route helpers are now `feed_monitor.source_fetch_path`, `feed_monitor.source_retry_path`, and `feed_monitor.source_bulk_scrape_path`.

### Upgrade Notes

1. Update your host `Gemfile` to the new version and run `rbenv exec bundle install`.
2. Re-run `rbenv exec bin/rails railties:install:migrations FROM=feed_monitor` followed by `rbenv exec bin/rails db:migrate` to apply new engine migrations (Solid Queue tables remain idempotent).
3. Diff `config/initializers/feed_monitor.rb` against the generated template to adopt new configuration defaults (queue visibility tweaks, HTTP knobs, mission control toggles).
4. If you surface Mission Control Jobs from the dashboard, ensure `mission_control-jobs` stays mounted and `config.mission_control_dashboard_path` points to the correct route helper.
5. Restart Solid Queue workers and Action Cable after deploying to pick up configuration changes.
