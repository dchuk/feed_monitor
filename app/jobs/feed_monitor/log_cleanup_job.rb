# frozen_string_literal: true

module FeedMonitor
  class LogCleanupJob < ApplicationJob
    DEFAULT_FETCH_LOG_RETENTION_DAYS = 90
    DEFAULT_SCRAPE_LOG_RETENTION_DAYS = 45

    feed_monitor_queue :fetch

    def perform(options = nil)
      options = normalize_options(options)

      now = resolve_time(options[:now])
      fetch_cutoff = resolve_cutoff(now:, days: options[:fetch_logs_older_than_days], default: DEFAULT_FETCH_LOG_RETENTION_DAYS)
      scrape_cutoff = resolve_cutoff(now:, days: options[:scrape_logs_older_than_days], default: DEFAULT_SCRAPE_LOG_RETENTION_DAYS)

      prune_fetch_logs(fetch_cutoff) if fetch_cutoff
      prune_scrape_logs(scrape_cutoff) if scrape_cutoff
    end

    private

    def normalize_options(options)
      case options
      when nil
        {}
      when Hash
        options.respond_to?(:symbolize_keys) ? options.symbolize_keys : options
      else
        {}
      end
    end

    def resolve_time(value)
      case value
      when nil
        Time.current
      when Time
        value
      when String
        Time.zone.parse(value) || Time.current
      else
        value.respond_to?(:to_time) ? value.to_time : Time.current
      end
    end

    def resolve_cutoff(now:, days:, default:)
      resolved_days =
        if days.nil?
          default
        else
          cast_to_integer(days)
        end

      return nil unless resolved_days
      return nil if resolved_days <= 0

      now - resolved_days.days
    end

    def cast_to_integer(value)
      return nil if value.nil?
      return value if value.is_a?(Integer)

      Integer(value, exception: false)
    end

    def prune_fetch_logs(cutoff)
      FeedMonitor::FetchLog.where(FeedMonitor::FetchLog.arel_table[:started_at].lt(cutoff))
        .in_batches(of: 500) { |batch| batch.delete_all }
    end

    def prune_scrape_logs(cutoff)
      FeedMonitor::ScrapeLog.where(FeedMonitor::ScrapeLog.arel_table[:started_at].lt(cutoff))
        .in_batches(of: 500) { |batch| batch.delete_all }
    end
  end
end

