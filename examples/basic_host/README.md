# Basic Feed Monitor Host

This template creates a Rails 8 application that mounts the Feed Monitor engine, installs its migrations, seeds a demo source, and redirects the root path to the dashboard.

## Generate the App

```bash
rbenv exec rails new feed_monitor_basic \
  --main \
  --database=postgresql \
  --skip-jbuilder \
  --skip-hotwire \
  -m ../path/to/examples/basic_host/template.rb
```

Replace `../path/to` with the relative path from the directory where you run `rails new`.

## What the Template Configures

- Adds the engine to the Gemfile via a local path.
- Runs `feed_monitor:install`, copies migrations, and executes `db:prepare`.
- Appends Feed Monitor Solid Queue processes to `Procfile.dev`.
- Seeds a sample Rails blog source so you can fetch content immediately.
- Redirects the application root to `/feed_monitor`.

## Next Steps

1. `cd feed_monitor_basic`
2. `cp config/database.yml config/database.local.yml` and adjust credentials if needed.
3. `bin/setup`
4. `bin/dev`

Once the worker fetches the seeded source, open <http://localhost:3000/feed_monitor> to browse items.

## Customization Ideas

- Update `config/initializers/feed_monitor.rb` to change queue names, HTTP timeouts, or scraping defaults.
- Add additional sources via the UI or `db/seeds.rb`.
- Switch the root redirect to a host dashboard once you embed the engine into a larger application.
