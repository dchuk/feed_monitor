FeedMonitor::Engine.routes.draw do
  get "/health", to: "health#show"
  resources :sources, only: %i[new create]
  root to: "home#index"
end
