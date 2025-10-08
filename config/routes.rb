FeedMonitor::Engine.routes.draw do
  get "/health", to: "health#show"
  root to: "home#index"
end
