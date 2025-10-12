# frozen_string_literal: true

# Feed Monitor engine configuration.
#
# These values default to conservative settings that work for most hosts.
# Tweak them here instead of monkey-patching the engine so upgrades remain easy.
FeedMonitor.configure do |config|
  # Namespace used when deriving queue names and instrumentation keys. If your
  # host app already prefixes queues (via ActiveJob.queue_name_prefix), this
  # string is automatically combined with that prefix.
  config.queue_namespace = "feed_monitor"

  # Dedicated queue names for fetching and scraping jobs. Solid Queue will use
  # these names when dispatching work; ensure they match entries in
  # config/solid_queue.yml (or your chosen Active Job backend).
  config.fetch_queue_name = "#{config.queue_namespace}_fetch"
  config.scrape_queue_name = "#{config.queue_namespace}_scrape"

  # Recommended worker concurrency for each queue when using Solid Queue.
  # Adjust to fit the workload and infrastructure available in the host app.
  config.fetch_queue_concurrency = 2
  config.scrape_queue_concurrency = 2

  # Solid Queue executes recurring "command" tasks via a job class. Override
  # this when host apps need additional context or instrumentation around
  # recurring commands.
  # config.recurring_command_job_class = "MyRecurringCommandJob"

  # Feed Monitor assumes Solid Queue handles persistence. Run
  # `bin/rails solid_queue:install` (dedicated queue database) or copy the
  # engine's Solid Queue migration into your app so Mission Control and the
  # dashboard can surface live queue metrics.

  # Toggle Feed Monitor's lightweight queue visibility layer. When enabled (the
  # default), the dashboard shows queue depth and last-run timestamps sourced
  # from ActiveSupport::Notifications.
  config.job_metrics_enabled = true

  # Mission Control integration is optional. Flip this to true to surface an
  # "Open Mission Control" link on the Feed Monitor dashboard.
  config.mission_control_enabled = false

  # Provide a String path ("/mission_control"), a route helper
  # (-> { Rails.application.routes.url_helpers.mission_control_jobs_path }),
  # or nil if you prefer not to link directly. This is only referenced when
  # mission_control_enabled is true. Ensure the host routes mount Mission
  # Control when supplying a path, for example:
  #   # Gemfile: gem "mission_control-jobs"
  #   # config/routes.rb:
  #   #   mount MissionControl::Jobs::Engine, at: "/mission_control"
  #   # config.mission_control_dashboard_path = "/mission_control"
  config.mission_control_dashboard_path = nil

  # ---- HTTP client -------------------------------------------------------
  # Tune the Faraday client Feed Monitor uses for fetches/scrapes.
  config.http.timeout = 15
  config.http.open_timeout = 5
  config.http.max_redirects = 5
  # config.http.proxy = ENV["FEED_MONITOR_HTTP_PROXY"]
  # config.http.retry_max = 4
  # config.http.retry_interval = 0.5
  # config.http.retry_backoff_factor = 2
  # config.http.retry_statuses = [429, 500, 502, 503, 504]
  # Merge extra default headers (User-Agent defaults to FeedMonitor/version).
  # config.http.headers = { "X-Request-ID" => -> { SecureRandom.uuid } }

  # ---- Adaptive fetch scheduling ----------------------------------------
  # Control how quickly sources speed up or back off when adaptive fetching
  # is enabled. Times are in minutes; factors must be positive numbers.
  # config.fetching.min_interval_minutes = 5    # lower bound (default: 5 minutes)
  # config.fetching.max_interval_minutes = 1440 # upper bound (default: 24 hours)
  # config.fetching.increase_factor = 1.25      # multiplier when no new items
  # config.fetching.decrease_factor = 0.75      # multiplier when new items arrive
  # config.fetching.failure_increase_factor = 1.5 # multiplier on errors/timeouts
  # config.fetching.jitter_percent = 0.1        # random jitter (0 disables jitter)

  # ---- Source health monitoring ---------------------------------------
  # Tune how many fetches Feed Monitor evaluates when determining health
  # status, as well as thresholds for warnings and automatic pauses.
  config.health.window_size = 20
  config.health.healthy_threshold = 0.8
  config.health.warning_threshold = 0.5
  config.health.auto_pause_threshold = 0.2
  config.health.auto_resume_threshold = 0.6
  config.health.auto_pause_cooldown_minutes = 60

  # ---- Scraper adapters --------------------------------------------------
  # Register additional scraper adapters or override built-ins. Adapters must
  # inherit from FeedMonitor::Scrapers::Base.
  # config.scrapers.register(:custom, "MyApp::Scrapers::CustomAdapter")

  # ---- Retention defaults ------------------------------------------------
  # Sources inherit these values when they leave retention fields blank.
  config.retention.items_retention_days = nil
  config.retention.max_items = nil
  # config.retention.strategy = :destroy # or :soft_delete

  # ---- Event callbacks ---------------------------------------------------
  # Integrate with host workflows by responding to engine events. Handlers
  # receive a single event object with helpful context. For example:
  #
  # config.events.after_item_created do |event|
  #   NewItemNotifier.publish(event.item, source: event.source)
  # end
  #
  # config.events.after_fetch_completed do |event|
  #   Rails.logger.info "Fetch for #{event.source.name} finished with #{event.status}"
  # end
  #
  # Register item processors to run after each entry is processed. These are
  # ideal for lightweight normalization or denormalized writes.
  # config.events.register_item_processor ->(context) { ItemIndexer.index(context.item) }

  # ---- Model extensions --------------------------------------------------
  # Host applications can extend Feed Monitor models without monkey patches.
  # Table names default to "feed_monitor_*"; override when multi-tenancy or
  # legacy naming requires a different prefix.
  # config.models.table_name_prefix = "feed_monitor_"
  #
  # Include extension concerns to add associations, scopes, or helper methods.
  # config.models.source.include_concern "MyApp::FeedMonitor::SourceExtensions"
  #
  # Register custom validations using a method name or a callable. Both forms
  # run within the model instance context, so you can reuse helpers defined in
  # your concerns.
  # config.models.source.validate :enforce_custom_rules
  # config.models.source.validate ->(record) { record.errors.add(:base, "custom error") }

  # ---- Realtime adapter -------------------------------------------------
  # Choose the Action Cable backend powering Turbo Streams. Solid Cable keeps
  # everything in the primary database so Redis is no longer required. Switch
  # to :redis if the host already runs a Redis cluster.
  config.realtime.adapter = :solid_cable
  # config.realtime.redis_url = ENV.fetch("FEED_MONITOR_REDIS_URL", nil)
  # config.realtime.solid_cable.polling_interval = "0.05.seconds"
  # config.realtime.solid_cable.message_retention = "12.hours"
  # config.realtime.solid_cable.connects_to = {
  #   database: { writing: :cable }
  # }
end
