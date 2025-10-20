# FeedMonitor

FeedMonitor is a production-ready Rails 8 mountable engine for ingesting, normalising, scraping, and monitoring RSS/Atom/JSON feeds. It ships with a Tailwind-powered admin UI, Solid Queue job orchestration, Solid Cable realtime broadcasting, and an extensible configuration layer so host applications can offer full-stack feed operations without rebuilding infrastructure.

## Highlights
- Full-featured source and item administration backed by Turbo Streams and Tailwind UI components
- Adaptive fetch pipeline (Feedjira + Faraday) with conditional GETs, retention pruning, and scrape orchestration
- Realtime dashboard metrics, batching/caching query layer, and Mission Control integration hooks
- Extensible scraper adapters (Readability included) with per-source settings and structured result metadata
- Declarative configuration DSL covering queues, HTTP, retention, events, model extensions, authentication, and realtime transports
- First-class observability through ActiveSupport notifications and `FeedMonitor::Metrics` counters/gauges

## Requirements
- Ruby 3.4.1+ (we recommend [rbenv](https://github.com/rbenv/rbenv) for local development: `rbenv install 3.4.1 && rbenv local 3.4.1`, but use whatever Ruby version manager suits your environment—asdf, chruby, rvm, or container-based workflows all work fine)
- Rails ≥ 8.0.2.1 in the host application
- PostgreSQL 13+ (engine migrations use JSONB, SKIP LOCKED, advisory locks, and Solid Cable tables)
- Node.js 18+ (npm or Yarn) for asset linting and the Tailwind/esbuild bundling pipeline
- Solid Queue workers (Rails 8 default) and Solid Cable (default realtime adapter)
- Optional: Mission Control Jobs for dashboard linking, Redis if you opt into the Redis realtime adapter

## Quick Start (Host Application)

> **Note on commands:** The examples below use bare `bundle` and `bin/rails` commands. If you use rbenv, prefix them with `rbenv exec` (e.g., `rbenv exec bundle install`). For Docker/container environments, run commands directly or via your container runtime. Adjust to match your Ruby version management approach.

### Initial Install
1. Add `gem "feed_monitor", github: "dchuk/feed_monitor"` to your Gemfile and run `bundle install`.
2. Install the engine: `bin/rails generate feed_monitor:install --mount-path=/feed_monitor` (updates routes, drops the initializer, prints doc links).
3. Copy migrations: `bin/rails railties:install:migrations FROM=feed_monitor`.
4. Apply migrations: `bin/rails db:migrate` (creates sources/items/logs tables, Solid Cable messages, and Solid Queue schema when required).
5. Install frontend tooling if you plan to extend engine assets: `npm install`.
6. Start background workers: `bin/rails solid_queue:start` (or your preferred process manager).
7. Boot your app and visit the mount path you chose (default `/feed_monitor`) to explore the dashboard and confirm Solid Queue metrics render.

Detailed instructions, optional flags, and verification steps live in [docs/installation.md](docs/installation.md), with troubleshooting advice in [docs/troubleshooting.md](docs/troubleshooting.md).

### Upgrading FeedMonitor
1. Bump the gem version in your host `Gemfile` and run `bundle install` (or `bundle update feed_monitor` when targeting a specific release).
2. Re-run `bin/rails railties:install:migrations FROM=feed_monitor` and then `bin/rails db:migrate` to pick up schema changes.
3. Compare your `config/initializers/feed_monitor.rb` against the newly generated template for configuration diffs (new queue knobs, HTTP options, etc.).
4. Review release notes for optional integrations—when enabling Mission Control, ensure `mission_control-jobs` stays mounted and linked via `config.mission_control_dashboard_path`.
5. Smoke test Solid Queue workers, Action Cable, and admin UI flows after the upgrade.

## Example Applications
- `examples/basic_host/template.rb` – Minimal host that seeds a Rails blog source and redirects `/` to the dashboard.
- `examples/advanced_host/template.rb` – Production-style integration with Mission Control, Redis realtime, Solid Queue tuning, and metrics endpoint.
- `examples/custom_adapter/template.rb` – Registers the sample Markdown scraper adapter and seeds a Markdown-based source.
- `examples/docker` – Dockerfile, Compose stack, and entrypoint script that run any generated example alongside Postgres and Redis.

See [examples/README.md](examples/README.md) for usage instructions.

## Architecture at a Glance
- **Source Lifecycle** – `FeedMonitor::Fetching::FetchRunner` coordinates advisory locking, fetch execution, retention pruning, and scrape enqueues. Source models store health metrics, failure states, and adaptive scheduling parameters.
- **Item Processing** – `FeedMonitor::Items::RetentionPruner`, `FeedMonitor::Scraping::Enqueuer`, and `FeedMonitor::Scraping::ItemScraper` keep content fresh, ensure deduplicated storage, and capture scrape metadata/logs.
- **Scraping Pipeline** – Adapters inherit from `FeedMonitor::Scrapers::Base`, merging default + source + invocation settings and returning structured results. The bundled Readability adapter composes `FeedMonitor::Scrapers::Fetchers::HttpFetcher` and `FeedMonitor::Scrapers::Parsers::ReadabilityParser`.
- **Realtime Dashboard** – `FeedMonitor::Dashboard::Queries` batches SQL, caches per-request responses, emits instrumentation (`feed_monitor.dashboard.*`), and coordinates Turbo broadcasts via Solid Cable.
- **Observability** – `FeedMonitor::Metrics` tracks counters/gauges for fetches, scheduler runs, and dashboard activity. ActiveSupport notifications (`feed_monitor.fetch.*`, `feed_monitor.scheduler.run`, etc.) let you instrument external systems without monkey patches.
- **Extensibility** – `FeedMonitor.configure` exposes namespaces for queue tuning, HTTP defaults, scraper registry, retention, event callbacks, model extensions, authentication hooks, realtime transports, health thresholds, and job metrics.

## Admin Experience
- Dashboard cards summarising source counts, recent activity, queue visibility, and upcoming fetch schedules
- Source CRUD with scraping toggles, adaptive fetch controls, manual fetch triggers, and detailed fetch log timelines
- Item explorer showing feed vs scraped content, scrape status badges, and manual scrape actions via Turbo
- Fetch/scrape log viewers with HTTP status, duration, backtrace, and Solid Queue job references

## Background Jobs & Scheduling
- Solid Queue becomes the Active Job adapter when the host app still uses the inline `:async` adapter; queue names default to `feed_monitor_fetch` and `feed_monitor_scrape` and honour `ActiveJob.queue_name_prefix`.
- `config/recurring.yml` schedules minute-level fetches and scrapes. Run `bin/jobs --recurring_schedule_file=config/recurring.yml` (or set `SOLID_QUEUE_RECURRING_SCHEDULE_FILE`) to load recurring tasks. Disable with `SOLID_QUEUE_SKIP_RECURRING=true`.
- Retry/backoff behaviour is driven by `FeedMonitor.configure.fetching`. Fetch completion events and item processors allow you to chain downstream workflows (indexing, notifications, etc.).

## Configuration & API Surface
The generated initializer documents every setting. Key areas:

- Queue namespace/concurrency helpers (`FeedMonitor.queue_name(:fetch)`)
- HTTP, retry, and proxy settings (Faraday-backed)
- Scraper registry (`config.scrapers.register(:my_adapter, "MyApp::Scrapers::Custom")`)
- Retention defaults (`config.retention.items_retention_days`, `config.retention.strategy`)
- Lifecycle hooks (`config.events.after_item_created`, `config.events.register_item_processor`)
- Model extensions (table prefixes, included concerns, custom validations)
- Realtime adapter selection (`config.realtime.adapter = :solid_cable | :redis | :async`)
- Authentication helpers (`config.authentication.authenticate_with`, `authorize_with`, etc.)
- Mission Control toggles (`config.mission_control_enabled`, `config.mission_control_dashboard_path`)
- Health thresholds driving automatic pause/resume

See [docs/configuration.md](docs/configuration.md) for exhaustive coverage and examples.

## Deployment Considerations
- Copy engine migrations before every deploy and run `bin/rails db:migrate`.
- Precompile assets so FeedMonitor's bundled CSS/JS outputs are available at runtime.
- Run dedicated Solid Queue worker processes; consider a separate scheduler process for recurring jobs.
- Configure Action Cable (Solid Cable by default) and expose `/cable` through your load balancer.
- Monitor gauges/counters emitted by `FeedMonitor::Metrics` and subscribe to notifications for alerting.

More production guidance, including process topology and scaling tips, is available in [docs/deployment.md](docs/deployment.md).

## Troubleshooting & Support
Common installation and runtime issues (missing migrations, realtime not streaming, scraping failures, queue visibility gaps) are documented in [docs/troubleshooting.md](docs/troubleshooting.md). When you report bugs, include your `FeedMonitor::VERSION`, Rails version, configuration snippet, and relevant fetch/scrape logs so we can reproduce quickly.

## Development & Testing (Engine Repository)
- Install dependencies with `bundle install` and `npm install` (prefix with `rbenv exec` if using rbenv).
- Use `test/dummy/bin/dev` to boot the dummy app with npm CSS/JS watchers, Solid Queue worker, and Rails server.
- Run tests via `bin/test-coverage` (SimpleCov-enforced), or `bin/rails test` for targeted suites.
- Quality checks: `bin/rubocop`, `bin/brakeman --no-pager`, `bin/lint-assets`.
- Record HTTP fixtures with VCR under `test/vcr_cassettes/` and keep coverage ≥ 90% for new code.

Contributions follow the clean architecture and TDD guidelines in `.ai/project_overview.md`. Review `.ai/tasks.md` to align with the active roadmap slice before opening a pull request.

## License
FeedMonitor is released under the [MIT License](MIT-LICENSE).
