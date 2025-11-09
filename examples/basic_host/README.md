# Basic SourceMonitor Host

This template creates a Rails 8 application that mounts the SourceMonitor engine, installs its migrations, seeds a demo source, and redirects the root path to the dashboard.

## Generate the App

```bash
rbenv exec rails new source_monitor_basic \
  --main \
  --database=postgresql \
  --skip-jbuilder \
  --skip-hotwire \
  -m ../path/to/examples/basic_host/template.rb
```

Replace `../path/to` with the relative path from the directory where you run `rails new`.

## What the Template Configures

- Adds the engine to the Gemfile via a local path.
- Runs `source_monitor:install`, copies migrations, and executes `db:prepare`.
- Appends SourceMonitor Solid Queue processes to `Procfile.dev`.
- Seeds a sample Rails blog source so you can fetch content immediately.
- Redirects the application root to `/source_monitor`.

## Next Steps

1. `cd source_monitor_basic`
2. `cp config/database.yml config/database.local.yml` and adjust credentials if needed.
3. `bin/setup`
4. `bin/dev`

Once the worker fetches the seeded source, open <http://localhost:3000/source_monitor> to browse items.

## Customization Ideas

- Update `config/initializers/source_monitor.rb` to change queue names, HTTP timeouts, or scraping defaults.
- Add additional sources via the UI or `db/seeds.rb`.
- Switch the root redirect to a host dashboard once you embed the engine into a larger application.
