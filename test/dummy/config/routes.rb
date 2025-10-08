Rails.application.routes.draw do
  mount FeedMonitor::Engine => "/feed_monitor"
end
