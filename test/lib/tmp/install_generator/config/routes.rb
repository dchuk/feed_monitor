Rails.application.routes.draw do
  mount FeedMonitor::Engine, at: "/feed_monitor"
end
