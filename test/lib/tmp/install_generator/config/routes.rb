Rails.application.routes.draw do
  mount FeedMonitor::Engine, at: "/admin/feed_monitor"
end
