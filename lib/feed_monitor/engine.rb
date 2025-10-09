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

        app.config.after_initialize do
          FeedMonitor::Jobs::Visibility.setup!
        end
      end
    end
  end
end
