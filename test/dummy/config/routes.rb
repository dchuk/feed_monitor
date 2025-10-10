Rails.application.routes.draw do
  mount ActionCable.server => "/cable"
  mount FeedMonitor::Engine => "/feed_monitor"
  if defined?(MissionControl::Jobs::Engine)
    mount MissionControl::Jobs::Engine, at: "/mission_control"
  end
end
