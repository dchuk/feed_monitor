Feedmon::Engine.routes.draw do
  get "/health", to: "health#show"
  get "/dashboard", to: "dashboard#index", as: :dashboard
  root to: "dashboard#index"
  resources :logs, only: :index
  resources :fetch_logs, only: :show
  resources :scrape_logs, only: :show
  resources :items, only: %i[index show] do
    post :scrape, on: :member
  end
  resources :sources do
    resource :fetch, only: :create, controller: "source_fetches"
    resource :retry, only: :create, controller: "source_retries"
    resource :bulk_scrape, only: :create, controller: "source_bulk_scrapes"
    resource :health_check, only: :create, controller: "source_health_checks"
    resource :health_reset, only: :create, controller: "source_health_resets"
  end
end
