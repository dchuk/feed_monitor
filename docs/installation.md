# Installation Guide

FeedMonitor installs like any other Rails engine, but it ships enough infrastructure (background jobs, realtime broadcasting, configuration DSL) that it is worth walking through the full setup. This guide assumes you are adding the engine to an existing Rails 8 host application.

## Prerequisites

- Ruby 3.4.4 (we recommend [rbenv](https://github.com/rbenv/rbenv) for local development: `rbenv install 3.4.4 && rbenv local 3.4.4`, but asdf, chruby, rvm, or container-managed Ruby all work equally well—choose whatever fits your environment)
- Rails 8.0.2.1 or newer
- PostgreSQL 13 or newer (the engine migrations rely on JSONB, SKIP LOCKED, and advisory locks)
- Node.js 18+ and npm or Yarn for asset linting/builds
- Solid Queue and Solid Cable gems available (they ship with Rails 8, but make sure they are not removed)
- Optional: Mission Control Jobs if you plan to surface the dashboard shortcut, Redis if you intend to switch realtime adapters

> **Command prefixes:** All commands below are shown without `rbenv exec`. If you use rbenv, prefix `bundle` and `bin/rails` commands with `rbenv exec`. For asdf, no prefix is needed. In Docker/container environments, run commands directly inside the container.

## Quick Reference

| Step | Command | Purpose |
| --- | --- | --- |
| 1 | `gem "feed_monitor", github: "dchuk/feed_monitor"` | Add the engine to your Gemfile |
| 2 | `bundle install` | Install Ruby dependencies |
| 3 | `bin/rails generate feed_monitor:install --mount-path=/feed_monitor` | Mount the engine and create the initializer |
| 4 | `bin/rails railties:install:migrations FROM=feed_monitor` | Copy engine migrations (idempotent) |
| 5 | `bin/rails db:migrate` | Apply schema updates, including Solid Queue tables |
| 6 | `bin/rails solid_queue:start` | Ensure jobs process via Solid Queue |
| 7 | `bin/jobs --recurring_schedule_file=config/recurring.yml` | Start recurring scheduler (optional but recommended) |

## 1. Add the Gem

In your host application's `Gemfile`:

```ruby
gem "feed_monitor", github: "dchuk/feed_monitor"
```

Then install dependencies:

```bash
bundle install
```

If you vendor node tooling for linting/assets in the host app, run `npm install` as well.

## 2. Run the Install Generator

The generator mounts the engine and drops an initializer stub for you to configure.

```bash
bin/rails generate feed_monitor:install --mount-path=/feed_monitor
```

Key outputs:

- Adds `mount FeedMonitor::Engine, at: "/feed_monitor"` to your routes (change the path with `--mount-path`)
- Creates `config/initializers/feed_monitor.rb` with documented configuration defaults
- The generator is idempotent: re-running it will detect existing mounts/initializers and skip overwriting your customizations
- Update your navigation or admin layout to link to the mount path so teammates can discover the dashboard.

## 3. Copy Engine Migrations

FeedMonitor relies on several tables (sources, items, fetch logs, scrape logs, Solid Cable messages, retention helpers) plus an optional Solid Queue schema. Copy them into your host application with:

```bash
bin/rails railties:install:migrations FROM=feed_monitor
```

This command is idempotent—re-run it when upgrading to pick up new migrations.

## 4. Run Database Migrations

Apply the new schema:

```bash
bin/rails db:migrate
```

If you prefer a dedicated database for Solid Queue, run `bin/rails solid_queue:install` beforehand and point the generated config at your queue database. Otherwise the engine-provided migration keeps Solid Queue tables in the primary database.

> Tip: Solid Queue tables must be present before you start the dashboard. If your host app already ran `solid_queue:install`, delete the engine-provided migration before running `db:migrate` to avoid duplication.

## 5. Wire Action Cable (if needed)

FeedMonitor defaults to Solid Cable for realtime. Rails expects `ApplicationCable::Connection` and `ApplicationCable::Channel` to exist in your host app:

```ruby
# app/channels/application_cable/connection.rb
module ApplicationCable
  class Connection < ActionCable::Connection::Base; end
end

# app/channels/application_cable/channel.rb
module ApplicationCable
  class Channel < ActionCable::Channel::Base; end
end
```

Verify `config/cable.yml` allows the adapter you choose. To switch to Redis, update `config/initializers/feed_monitor.rb` with `config.realtime.adapter = :redis` and provide `config.realtime.redis_url`.

## 6. Configure Background Workers

Solid Queue becomes the default Active Job adapter when the host app still uses `:async`. Keep at least one worker process running:

```bash
# long-running process
bin/rails solid_queue:start
```

Feed Monitor respects explicit queue adapter overrides. If your host sets `config.active_job.queue_adapter` (for example, to `:inline` or `:sidekiq`), the engine leaves that configuration in place.

For recurring schedules, add a process that runs the Solid Queue CLI with the engine's schedule file:

```bash
bin/jobs --recurring_schedule_file=config/recurring.yml
```

Set `SOLID_QUEUE_SKIP_RECURRING=true` in environments that manage recurring tasks elsewhere.

## 7. Review Configuration Defaults

Open `config/initializers/feed_monitor.rb` and adjust queue namespaces, HTTP timeouts, scraping adapters, retention limits, authentication hooks, and Mission Control integration to match your environment. The [configuration reference](configuration.md) covers every option with examples.

## 8. Verify the Installation

1. Start your Rails server: `bin/rails server`
2. Ensure a Solid Queue worker is running (see step 6)
3. Visit the mount path (`/feed_monitor` by default)
4. Create a source and trigger `Fetch Now`—watch fetch logs appear and dashboard metrics update

If you encounter issues, consult the [troubleshooting guide](troubleshooting.md).

## Next Steps

- Explore the admin UI and dashboards
- Integrate custom scraper adapters or item processors via `FeedMonitor.configure`
- Set up monitoring for the Solid Queue queues using Mission Control or your preferred observability stack

## Host Compatibility Matrix

| Host Scenario | Status | Notes |
| --- | --- | --- |
| Rails 8 full-stack app | ✅ Supported | Default generator flow (mount + initializer) |
| Rails 8 API-only app (`--api`) | ✅ Supported | Generator mounts engine; ensure you provide a UI entry point if needed |
| Dedicated Solid Queue database | ✅ Supported | Run `bin/rails solid_queue:install` in the host app before copying Feed Monitor migrations |
| Redis-backed Action Cable | ✅ Supported | Set `config.realtime.adapter = :redis` and provide `config.realtime.redis_url`; existing `config/cable.yml` entries are preserved |
