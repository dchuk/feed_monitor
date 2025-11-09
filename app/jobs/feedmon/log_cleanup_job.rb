# frozen_string_literal: true

module Feedmon
  class LogCleanupJob < ApplicationJob
    DEFAULT_FETCH_LOG_RETENTION_DAYS = 90
    DEFAULT_SCRAPE_LOG_RETENTION_DAYS = 45

    feedmon_queue :fetch

    def perform(options = nil)
      options = Feedmon::Jobs::CleanupOptions.normalize(options)

      now = Feedmon::Jobs::CleanupOptions.resolve_time(options[:now])
      fetch_cutoff = resolve_cutoff(now:, days: options[:fetch_logs_older_than_days], default: DEFAULT_FETCH_LOG_RETENTION_DAYS)
      scrape_cutoff = resolve_cutoff(now:, days: options[:scrape_logs_older_than_days], default: DEFAULT_SCRAPE_LOG_RETENTION_DAYS)

      prune_fetch_logs(fetch_cutoff) if fetch_cutoff
      prune_scrape_logs(scrape_cutoff) if scrape_cutoff
    end

    private

    def resolve_cutoff(now:, days:, default:)
      resolved_days =
        if days.nil?
          default
        else
          Feedmon::Jobs::CleanupOptions.integer(days)
        end

      return nil unless resolved_days
      return nil if resolved_days <= 0

      now - resolved_days.days
    end

    def prune_fetch_logs(cutoff)
      Feedmon::FetchLog.where(Feedmon::FetchLog.arel_table[:started_at].lt(cutoff))
        .in_batches(of: 500) { |batch| batch.delete_all }
    end

    def prune_scrape_logs(cutoff)
      Feedmon::ScrapeLog.where(Feedmon::ScrapeLog.arel_table[:started_at].lt(cutoff))
        .in_batches(of: 500) { |batch| batch.delete_all }
    end
  end
end
