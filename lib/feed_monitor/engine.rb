module FeedMonitor
  class Engine < ::Rails::Engine
    isolate_namespace FeedMonitor

    initializer "feed_monitor.assets" do |app|
      app.config.assets.paths << root.join("app/assets/builds")
    end

    initializer "feed_monitor.metrics" do
      FeedMonitor::Metrics.setup_subscribers!
    end
  end
end
