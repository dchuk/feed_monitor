Rails.application.routes.draw do
  mount FeedMonitor::Engine, at: "/reader"
end
