module FeedMonitor
  class Engine < ::Rails::Engine
    isolate_namespace FeedMonitor

    initializer "feed_monitor.assets" do |app|
      app.config.assets.paths << root.join("app/assets/builds")
    end

    initializer "feed_monitor.metrics" do
      FeedMonitor::Metrics.setup_subscribers!
    end

    initializer "feed_monitor.jobs" do |app|
      FeedMonitor::Jobs::Visibility.setup!

      if defined?(::SolidQueue)
        adapter_name = ActiveJob::Base.queue_adapter_name.to_s
        if adapter_name.empty? || adapter_name == "async"
          ActiveJob::Base.queue_adapter = :solid_queue
        end

        if defined?(::SolidQueue::RecurringTask)
          job_class_config = FeedMonitor.config.recurring_command_job_class
          if job_class_config.present?
            resolved_class = job_class_config.is_a?(String) ? job_class_config.constantize : job_class_config
            SolidQueue::RecurringTask.default_job_class = resolved_class
          end
        end

        if defined?(MissionControl::Jobs)
          adapters = MissionControl::Jobs.adapters
          if adapters.respond_to?(:add)
            adapters.add(:solid_queue)
            adapters.delete(:async)
          elsif adapters.respond_to?(:<<)
            adapters << :solid_queue unless adapters.include?(:solid_queue)
            adapters.delete(:async) if adapters.respond_to?(:delete)
          end

          if defined?(ActiveJob::QueueAdapters::SolidQueueExt) &&
              !(ActiveJob::QueueAdapters::SolidQueueAdapter < ActiveJob::QueueAdapters::SolidQueueExt)
            ActiveJob::QueueAdapters::SolidQueueAdapter.prepend ActiveJob::QueueAdapters::SolidQueueExt
          end

          MissionControl::Jobs.applications.each do |application|
            next if application.servers.any? { |server| server.queue_adapter_name == :solid_queue }

            solid_queue_adapter = ActiveJob::QueueAdapters.lookup(:solid_queue).new
            application.add_servers(solid_queue: solid_queue_adapter)
          end
        end

        app.config.after_initialize do
          FeedMonitor::Jobs::Visibility.setup!
        end
      end
    end
  end
end
