# Deployment Guide

This guide captures the production considerations for running FeedMonitor inside a host Rails application. Pair it with your platform playbook (Heroku, Render, Kubernetes, etc.) for environment-specific instructions.

## Build & Release Pipeline

1. **Install dependencies** – use `rbenv exec bundle install` and `npm install` during build steps.
2. **Copy and run migrations** – always run `bin/rails railties:install:migrations FROM=feed_monitor` before `bin/rails db:migrate` so new engine tables ship with each release.
3. **Precompile assets** – `bin/rails assets:precompile` pulls in FeedMonitor's Tailwind build, importmap, and stimulus controllers. Fail the build if `feed_monitor:assets:verify` raises.
4. **Run quality gates** – `bin/rubocop`, `bin/brakeman --no-pager`, `bin/lint-assets`, and `bin/test-coverage` mirror the repository CI setup.

## Process Model

FeedMonitor assumes the standard Rails 8 process split:

- **Web** – your application server (Puma) serving the mounted engine and Action Cable. When using Solid Cable, no separate Redis process is required.
- **Worker** – at least one Solid Queue worker (`bin/rails solid_queue:start`). Scale horizontally to match feed volume and retention pruning needs. Use queue selectors if you dedicate workers to `feed_monitor_fetch` or `feed_monitor_scrape`.
- **Scheduler/Recurring** – optional process invoking `bin/jobs --recurring_schedule_file=config/recurring.yml` so the bundled recurring tasks enqueue fetch/scrape/cleanup jobs. Disable with `SOLID_QUEUE_SKIP_RECURRING=true` when another scheduler handles cron-style jobs.

## Database & Storage

- **Primary Database** – hosts sources, items, logs, and Solid Cable messages. Ensure autovacuum keeps up; retention pruning helps bound growth.
- **Solid Queue Database (optional)** – create a dedicated connection via `rails solid_queue:install` if queue load warrants isolation. Update the generated config before running migrations.
- **Backups** – include Solid Queue tables in backups if they share the primary database; they store job state.

## Observability & Alerting

- Subscribe to ActiveSupport notifications (`feed_monitor.fetch.finish`, `feed_monitor.scheduler.run`, `feed_monitor.dashboard.*`) to emit logs or metrics into your monitoring stack.
- Scrape `FeedMonitor::Metrics.snapshot` periodically (e.g., via a health check controller) to track counters and gauges in Prometheus or StatsD.
- Mission Control integration becomes useful once queues exceed a few hundred jobs; enable it when your platform already hosts the Mission Control UI.

## Security & Authentication

- Lock down the engine routes with authentication hooks (`config.authentication.authenticate_with` / `authorize_with`).
- Configure HTTPS for Action Cable if you expose Solid Cable over the public internet.
- Store API keys for authenticated feeds in encrypted credentials and inject them via per-source custom headers.

## Scaling Guidelines

- Increase `config.fetch_queue_concurrency` and the number of Solid Queue workers as source volume grows.
- Adjust `config.fetching` multipliers to smooth out noisy feeds; raising `failure_increase_factor` slows retries for consistently failing sources.
- Use `config.retention` to cap database growth; nightly cleanup jobs can run on separate workers if pruning becomes heavy.

## Rolling Upgrades

1. Merge and deploy code.
2. Run migrations before restarting workers so new tables/columns exist before jobs enqueue.
3. Restart Solid Queue workers after deploy so they load updated configuration and code.
4. Verify the dashboard loads, queue counts appear, and Mission Control links resolve when enabled.

## Disaster Recovery Checklist

- Restore the database, then replay any external feed data if necessary (FeedMonitor deduplicates using GUID/fingerprint).
- Resume Solid Queue workers and monitor `fetch_failed_total` gauge for anomalies.
- Rebuild assets if you deploy to ephemeral filesystems.

Keep this guide alongside your platform runbooks so teams can confidently deploy and operate FeedMonitor in any environment.

## Container Reference Stack

The repository ships a reusable Docker stack under `examples/docker` that mirrors the recommended process model. It builds a Ruby 3.3 image with Node, mounts your generated example via `APP_PATH`, and launches three services (`web`, `worker`, `scheduler`) alongside Postgres and Redis. Use it to trial production settings locally or as a baseline for ECS/Kubernetes manifests.
