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
