# Changelog

## Release Checklist

1. `rbenv exec bundle exec rails test`
2. `rbenv exec bundle exec rubocop`
3. `rbenv exec bundle exec rake app:feed_monitor:assets:verify`
4. `rbenv exec bundle exec gem build feed_monitor.gemspec`
5. Update release notes in this file and tag the release (`git tag vX.Y.Z`)
6. Push tags and publish the gem (`rbenv exec gem push pkg/feed_monitor-X.Y.Z.gem`)

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
