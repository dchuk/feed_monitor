module Feedmon
  parent_job = defined?(::ApplicationJob) ? ::ApplicationJob : ActiveJob::Base

  class ApplicationJob < parent_job
    class << self
      # Specify a queue name using Feedmon's configuration, ensuring
      # we respect host application prefixes and overrides.
      def feedmon_queue(role)
        queue_as Feedmon.queue_name(role)
      end
    end
  end
end
