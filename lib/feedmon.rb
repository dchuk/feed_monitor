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

require "feedmon/version"
require "active_support/core_ext/module/redefine_method"

Feedmon.singleton_class.redefine_method(:table_name_prefix) do
  Feedmon::Engine.table_name_prefix
end

ActiveSupport.on_load(:active_record) do
  Feedmon.singleton_class.redefine_method(:table_name_prefix) do
    Feedmon::Engine.table_name_prefix
  end
end

require "feedmon/engine"
require "feedmon/configuration"
require "feedmon/model_extensions"
require "feedmon/events"
require "feedmon/instrumentation"
require "feedmon/metrics"
require "feedmon/http"
require "feedmon/feedjira_extensions"
require "feedmon/dashboard/quick_action"
require "feedmon/dashboard/recent_activity"
require "feedmon/dashboard/recent_activity_presenter"
require "feedmon/dashboard/quick_actions_presenter"
require "feedmon/dashboard/queries"
require "feedmon/dashboard/turbo_broadcaster"
require "feedmon/logs/entry_sync"
require "feedmon/logs/filter_set"
require "feedmon/logs/query"
require "feedmon/logs/table_presenter"
require "feedmon/realtime"
require "feedmon/analytics/source_fetch_interval_distribution"
require "feedmon/analytics/source_activity_rates"
require "feedmon/analytics/sources_index_metrics"
require "feedmon/jobs/cleanup_options"
require "feedmon/jobs/visibility"
require "feedmon/jobs/solid_queue_metrics"
require "feedmon/security/parameter_sanitizer"
require "feedmon/security/authentication"
require "feedmon/pagination/paginator"
require "feedmon/turbo_streams/stream_responder"
require "feedmon/scrapers/base"
require "feedmon/scrapers/fetchers/http_fetcher"
require "feedmon/scrapers/parsers/readability_parser"
require "feedmon/scrapers/readability"
require "feedmon/scraping/enqueuer"
require "feedmon/scraping/bulk_source_scraper"
require "feedmon/scraping/state"
require "feedmon/scraping/scheduler"
require "feedmon/scraping/item_scraper"
require "feedmon/fetching/fetch_error"
require "feedmon/fetching/feed_fetcher"
require "feedmon/items/retention_pruner"
require "feedmon/fetching/fetch_runner"
require "feedmon/scheduler"
require "feedmon/items/item_creator"
require "feedmon/health"
require "feedmon/assets"

module Feedmon
  class << self
    def configure
      yield config
      Feedmon::ModelExtensions.reload!
    end

    def config
      @config ||= Configuration.new
    end

    def events
      config.events
    end

    def reset_configuration!
      @config = Configuration.new
      Feedmon::ModelExtensions.reload!
      Feedmon::Health.setup!
      Feedmon::Realtime.setup!
      Feedmon::Dashboard::TurboBroadcaster.setup!
    end

    def queue_name(role)
      config.queue_name_for(role)
    end

    def queue_concurrency(role)
      config.concurrency_for(role)
    end

    def table_name_prefix
      Feedmon::Engine.table_name_prefix
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
