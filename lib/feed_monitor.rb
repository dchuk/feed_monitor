begin
  require "solid_queue"
rescue LoadError
  # Solid Queue is optional if the host app supplies a different Active Job backend.
end

require "feed_monitor/version"
require "feed_monitor/engine"
require "feed_monitor/configuration"
require "feed_monitor/instrumentation"
require "feed_monitor/metrics"
require "feed_monitor/http"
require "feed_monitor/feedjira_extensions"
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
    end

    def config
      @config ||= Configuration.new
    end

    def reset_configuration!
      @config = Configuration.new
    end

    def queue_name(role)
      config.queue_name_for(role)
    end

    def queue_concurrency(role)
      config.concurrency_for(role)
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
