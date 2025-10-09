# frozen_string_literal: true

module FeedMonitor
  class Configuration
    attr_accessor :queue_namespace,
      :fetch_queue_name,
      :scrape_queue_name,
      :fetch_queue_concurrency,
      :scrape_queue_concurrency,
      :job_metrics_enabled,
      :mission_control_enabled,
      :mission_control_dashboard_path

    DEFAULT_QUEUE_NAMESPACE = "feed_monitor"

    def initialize
      @queue_namespace = DEFAULT_QUEUE_NAMESPACE
      @fetch_queue_name = "#{DEFAULT_QUEUE_NAMESPACE}_fetch"
      @scrape_queue_name = "#{DEFAULT_QUEUE_NAMESPACE}_scrape"
      @fetch_queue_concurrency = 2
      @scrape_queue_concurrency = 2
      @job_metrics_enabled = true
      @mission_control_enabled = false
      @mission_control_dashboard_path = nil
    end

    def queue_name_for(role)
      explicit_name =
        case role.to_sym
        when :fetch
          fetch_queue_name
        when :scrape
          scrape_queue_name
        else
          raise ArgumentError, "unknown queue role #{role.inspect}"
        end

      prefix = ActiveJob::Base.queue_name_prefix
      delimiter = ActiveJob::Base.queue_name_delimiter

      if prefix && !prefix.empty?
        [prefix, explicit_name].join(delimiter)
      else
        explicit_name
      end
    end

    def concurrency_for(role)
      case role.to_sym
      when :fetch
        fetch_queue_concurrency
      when :scrape
        scrape_queue_concurrency
      else
        raise ArgumentError, "unknown queue role #{role.inspect}"
      end
    end
  end
end
