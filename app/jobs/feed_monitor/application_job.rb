module FeedMonitor
  parent_job = defined?(::ApplicationJob) ? ::ApplicationJob : ActiveJob::Base

  class ApplicationJob < parent_job
    class << self
      # Specify a queue name using FeedMonitor's configuration, ensuring
      # we respect host application prefixes and overrides.
      def feed_monitor_queue(role)
        queue_as FeedMonitor.queue_name(role)
      end
    end
  end
end
