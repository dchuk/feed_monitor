# Custom Scraper Adapter Example

This example ships a Markdown scraping adapter that subclasses `Feedmon::Scrapers::Base`. Use it when your feeds supply Markdown payloads that you want to render as HTML with a plain-text fallback.

## Generate the App

```bash
rbenv exec rails new feedmon_custom_adapter \
  --main \
  --database=postgresql \
  -m ../path/to/examples/custom_adapter/template.rb
```

## What You Get

- The adapter is copied to `lib/feedmon/examples/scrapers/markdown_scraper.rb`.
- `Feedmon.configure` registers the adapter under the `:markdown` key.
- Seeds create a demo source that uses the adapter automatically.
- Documentation is copied into `README.feedmon.md` with usage notes.

## Registering the Adapter Manually

If you want to integrate the adapter into an existing host:

1. Copy `examples/custom_adapter/lib/feedmon/examples/scrapers/markdown_scraper.rb` into your app (any autoloaded path works).
2. Add `config.scrapers.register(:markdown, "Feedmon::Examples::Scrapers::MarkdownScraper")` to your Feedmon initializer.
3. Set `scraper_adapter` to `"markdown"` on any sources that publish Markdown.

## Settings

The adapter merges settings in the usual order (defaults → source overrides → invocation overrides). It supports:

- `wrap_in_article` (default `true`) – Wraps HTML output in `<article data-scraper="markdown">`.
- `include_plain_text` (default `true`) – Controls whether the plain-text version is exposed in the result.

Per-source overrides can be supplied through the UI or seeds: `source.scrape_settings = { include_plain_text: false }`.
