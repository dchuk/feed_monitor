# frozen_string_literal: true

namespace :feed_monitor do
  namespace :maintenance do
    desc "Recover sources stuck in the fetching state when Solid Queue workers crash"
    task recover_stalled_fetches: :environment do
      result = FeedMonitor::Fetching::StalledFetchReconciler.call

      recovered_count = result.recovered_source_ids.size
      removed_jobs_count = result.jobs_removed.size

      puts "Recovered #{recovered_count} stalled sources."
      puts "Removed #{removed_jobs_count} orphaned job#{'s' unless removed_jobs_count == 1}."
    end
  end
end
