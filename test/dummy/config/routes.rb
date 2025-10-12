Rails.application.routes.draw do
  mount ActionCable.server => "/cable"
  get "/test_support/dropdown_without_dependency", to: "test_support#dropdown_without_dependency"
  mount FeedMonitor::Engine => "/feed_monitor"
  if defined?(MissionControl::Jobs::Engine)
    mount MissionControl::Jobs::Engine, at: "/mission_control"
  end
end
