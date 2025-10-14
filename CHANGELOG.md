# Changelog

## 2025-10-14

- Converted source fetch, retry, and bulk scrape member actions into nested resources. New controller endpoints:
  - `POST /feed_monitor/sources/:source_id/fetch` (`FeedMonitor::SourceFetchesController#create`)
  - `POST /feed_monitor/sources/:source_id/retry` (`FeedMonitor::SourceRetriesController#create`)
  - `POST /feed_monitor/sources/:source_id/bulk_scrape` (`FeedMonitor::SourceBulkScrapesController#create`)
  Route helpers are now `feed_monitor.source_fetch_path`, `feed_monitor.source_retry_path`, and `feed_monitor.source_bulk_scrape_path`.
