FeedMonitor::Engine.routes.draw do
  get "/health", to: "health#show"
  get "/welcome", to: "home#index"
  get "/dashboard", to: "dashboard#index", as: :dashboard
  root to: "dashboard#index"
  resources :sources, only: %i[new create]
end
