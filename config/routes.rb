FeedMonitor::Engine.routes.draw do
  get "/health", to: "health#show"
  get "/dashboard", to: "dashboard#index", as: :dashboard
  root to: "dashboard#index"
  resources :fetch_logs, only: %i[index show]
  resources :scrape_logs, only: %i[index show]
  resources :items, only: %i[index show]
  resources :sources do
    post :fetch, on: :member
  end
end
