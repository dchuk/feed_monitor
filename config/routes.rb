FeedMonitor::Engine.routes.draw do
  get "/health", to: "health#show"
  get "/dashboard", to: "dashboard#index", as: :dashboard
  root to: "dashboard#index"
  resources :fetch_logs, only: %i[index show]
  resources :scrape_logs, only: %i[index show]
  resources :items, only: %i[index show] do
    post :scrape, on: :member
  end
  resources :sources do
    resource :fetch, only: :create, controller: "source_fetches"
    resource :retry, only: :create, controller: "source_retries"
    resource :bulk_scrape, only: :create, controller: "source_bulk_scrapes"
  end
end
