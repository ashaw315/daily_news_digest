Rails.application.routes.draw do
  devise_for :users

  resource :preferences, only: [:edit, :update] do
    post :reset, on: :collection
  end
  
  # Public home page that doesn't require authentication
  get 'home', to: 'home#index'
  root to: 'home#index'

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Defines the root path route ("/")
  # root "posts#index"

    # Articles
    resources :articles, only: [:index, :show]

  # Email tracking
  get 'email/track/:token', to: 'email_tracking#track', as: 'email_tracking'

  # Unsubscribe
  get 'unsubscribe/:token', to: 'subscriptions#unsubscribe', as: 'unsubscribe'

  # Dashboard route
  # get 'dashboard', to: 'dashboard#index', as: 'dashboard'

   # Admin routes
   namespace :admin do
    get 'dashboard', to: 'dashboard#index'
    resources :topics
    resources :news_sources
    resources :users, only: [:index, :show]
    resources :email_metrics, only: [:index]
  end
end
