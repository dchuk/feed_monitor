FeedMonitor::Engine.routes.draw do
  get "/health", to: "health#show"
  get "/dashboard", to: "dashboard#index", as: :dashboard
  root to: "dashboard#index"
  resources :items, only: %i[index show]
  resources :sources
end
