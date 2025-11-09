# Advanced SourceMonitor Host

This template provisions a Rails 8 application that demonstrates a production-style integration:

- Mounts the engine under `/operations/source_monitor`
- Enables Mission Control linking and mounts the Mission Control Jobs UI
- Switches realtime updates to Redis
- Copies a Solid Queue configuration with dedicated fetch/scrape concurrency
- Adds an authenticated `/source_monitor/metrics` endpoint
- Wires log-friendly instrumentation subscribers

## Generate the App

```bash
rbenv exec rails new source_monitor_advanced \
  --main \
  --css=tailwind \
  --database=postgresql \
  -m ../path/to/examples/advanced_host/template.rb
```

## Environment Variables

Create a `.env` or export the following before running `bin/dev`:

- `DATABASE_URL` – Point at your Postgres instance.
- `REDIS_URL` – Required for the Redis Action Cable adapter.
- `SOURCE_MONITOR_METRICS_USER` / `SOURCE_MONITOR_METRICS_PASS` – Credentials for the metrics endpoint.

## Process Model

The template appends the following entries to `Procfile.dev`:

- `web` – Rails server.
- `worker` – `bin/rails solid_queue:start`.
- `jobs` – `bin/jobs --recurring_schedule_file=config/recurring.yml`.

When deploying to production, run each process in its own container or dyno.

## Instrumentation

Review `config/initializers/source_monitor_instrumentation.rb` to see how ActiveSupport notifications can be bridged into your logging stack. Adjust the regex or payload filtering to match the events you care about.

## Mission Control

The template mounts Mission Control Jobs at `/mission_control`. Authenticate it the same way you authenticate the SourceMonitor dashboard (Devise, OmniAuth, etc.).

## Next Steps

1. `cd source_monitor_advanced`
2. `bin/setup`
3. `bin/dev`

Visit:

- <http://localhost:3000/operations/source_monitor> – SourceMonitor dashboard.
- <http://localhost:3000/mission_control> – Mission Control Jobs UI.
- <http://localhost:3000/source_monitor/metrics> – Metrics JSON (basic auth).

Review `config/initializers/source_monitor.rb` for additional knobs (HTTP retries, retention, custom processors) once you're ready to harden for production workloads.
