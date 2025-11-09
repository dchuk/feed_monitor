# Feedmon Example Applications

This directory ships application templates and supporting assets that demonstrate how to host the Feedmon engine from a Rails application. Each template follows the Rails application template API, so you can generate a fresh host app with `rails new ... -m path/to/template.rb` and the template will configure Feedmon for you.

## Available Templates

- **Basic Host (`basic_host/template.rb`)** – Creates a minimal Rails 8 app that mounts the engine at `/feedmon`, installs the engine migrations, seeds a demo source, and redirects the root path to the dashboard.
- **Advanced Host (`advanced_host/template.rb`)** – Builds on the basic example with production-style Solid Queue workers, Mission Control dashboard linking, instrumentation subscribers, and queue-specific Procfile entries.
- **Custom Adapter (`custom_adapter/template.rb`)** – Generates a host that registers the sample Markdown scraping adapter defined in `examples/custom_adapter/markdown_scraper.rb` and wires it into the engine configuration.

Each template copies the accompanying README into the generated application so teams can follow next steps in context.

## Docker Assets

`examples/docker` contains a shared `Dockerfile`, Compose file, and entrypoint scripts that you can reuse with any generated example. Mount the generated host app into the container (or build an image from it) to run the web, worker, and recurring scheduler processes alongside Postgres.

## Usage

1. Ensure you have Rails 8 installed (`gem install rails`) and Postgres available locally.
2. From the repository root, run `rails new my_app --main --database=postgresql -m examples/basic_host/template.rb` (or substitute one of the other templates).
3. Follow the generated README under your new application's directory for environment variables, `bin/setup`, and `bin/dev` instructions.

See `docs/deployment.md` for production hardening guidance once you're ready to promote an example into a real environment.
