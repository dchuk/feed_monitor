begin
  require "solid_queue"
rescue LoadError
  # Solid Queue is optional if the host app supplies a different Active Job backend.
end

begin
  require "solid_cable"
rescue LoadError
  # Solid Cable is optional if the host app uses Redis or another Action Cable adapter.
end

begin
  require "turbo-rails"
rescue LoadError
  # Turbo is optional but recommended for real-time updates.
end

begin
  require "ransack"
rescue LoadError
  # Ransack powers search forms when available.
end

require "active_support/core_ext/module/redefine_method"

FeedMonitor.singleton_class.redefine_method(:table_name_prefix) do
  FeedMonitor::Engine.table_name_prefix
end

ActiveSupport.on_load(:active_record) do
  FeedMonitor.singleton_class.redefine_method(:table_name_prefix) do
    FeedMonitor::Engine.table_name_prefix
  end
end

require "feed_monitor/version"
require "feed_monitor/engine"
require "feed_monitor/configuration"
require "feed_monitor/model_extensions"
require "feed_monitor/events"
require "feed_monitor/instrumentation"
require "feed_monitor/metrics"
require "feed_monitor/http"
require "feed_monitor/feedjira_extensions"
require "feed_monitor/dashboard/queries"
require "feed_monitor/dashboard/turbo_broadcaster"
require "feed_monitor/realtime"
require "feed_monitor/analytics/source_fetch_interval_distribution"
require "feed_monitor/analytics/source_activity_rates"
require "feed_monitor/jobs/visibility"
require "feed_monitor/jobs/solid_queue_metrics"
require "feed_monitor/scrapers/base"
require "feed_monitor/scrapers/fetchers/http_fetcher"
require "feed_monitor/scrapers/parsers/readability_parser"
require "feed_monitor/scrapers/readability"
require "feed_monitor/scraping/enqueuer"
require "feed_monitor/scraping/scheduler"
require "feed_monitor/scraping/item_scraper"
require "feed_monitor/fetching/fetch_error"
require "feed_monitor/fetching/feed_fetcher"
require "feed_monitor/items/retention_pruner"
require "feed_monitor/fetching/fetch_runner"
require "feed_monitor/scheduler"
require "feed_monitor/items/item_creator"

module FeedMonitor
  class << self
    def configure
      yield config
      FeedMonitor::ModelExtensions.reload!
    end

    def config
      @config ||= Configuration.new
    end

    def events
      config.events
    end

    def reset_configuration!
      @config = Configuration.new
      FeedMonitor::ModelExtensions.reload!
      FeedMonitor::Dashboard::TurboBroadcaster.setup!
      FeedMonitor::Realtime.setup!
    end

    def queue_name(role)
      config.queue_name_for(role)
    end

    def queue_concurrency(role)
      config.concurrency_for(role)
    end

    def table_name_prefix
      FeedMonitor::Engine.table_name_prefix
    end

    def mission_control_enabled?
      config.mission_control_enabled
    end

    def mission_control_dashboard_path
      raw_path = config.mission_control_dashboard_path
      resolved = resolve_callable(raw_path)
      return if resolved.blank?

      valid_dashboard_path?(resolved) ? resolved : nil
    rescue StandardError
      nil
    end

    private

    def resolve_callable(value)
      value.respond_to?(:call) ? value.call : value
    end

    def valid_dashboard_path?(value)
      return true if value.to_s.match?(%r{\Ahttps?://})

      Rails.application.routes.recognize_path(value, method: :get)
      true
    rescue ActionController::RoutingError
      false
    end
  end
end
