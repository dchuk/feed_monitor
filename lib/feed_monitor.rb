require "feed_monitor/version"
require "feed_monitor/engine"
require "feed_monitor/configuration"
require "feed_monitor/instrumentation"
require "feed_monitor/metrics"
require "feed_monitor/http"
require "feed_monitor/feedjira_extensions"
require "feed_monitor/jobs/visibility"
require "feed_monitor/scrapers/base"
require "feed_monitor/scrapers/fetchers/http_fetcher"
require "feed_monitor/scrapers/parsers/readability_parser"
require "feed_monitor/scrapers/readability"
require "feed_monitor/scraping/enqueuer"
require "feed_monitor/scraping/item_scraper"
require "feed_monitor/fetching/fetch_error"
require "feed_monitor/fetching/feed_fetcher"
require "feed_monitor/fetching/fetch_runner"
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
      path = config.mission_control_dashboard_path
      path.respond_to?(:call) ? path.call : path
    rescue StandardError
      nil
    end
  end
end
