# FeedMonitor
Short description and motivation.

## Usage
How to use my plugin.

## Installation
Add this line to your application's Gemfile:

```ruby
gem "feed_monitor"
```

And then execute:
```bash
$ bundle
```

Mount the engine inside your host application's routes with the install generator:

```bash
$ bin/rails generate feed_monitor:install
```

By default the engine mounts at `/feed_monitor`. Provide a custom mount point with the `--mount-path` option:

```bash
$ bin/rails generate feed_monitor:install --mount-path=/admin/feeds
```

## Contributing
Contribution directions go here.

## License
The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
