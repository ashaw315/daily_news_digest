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
    # Cron job endpoints
    get 'cron/purge_articles'
    get 'cron/fetch_articles'
    get 'cron/schedule_daily_emails'

    # Dashboard
    get 'dashboard', to: 'dashboard#index'
    get 'email_debug', to: 'dashboard#email_debug'
    get 'sendgrid_status', to: 'dashboard#check_sendgrid_status'
    get 'email_test_suite', to: 'dashboard#email_test_suite'

    # Resources
    resources :topics
    
    resources :users, only: [:index, :show, :destroy] do
      post :send_test_email, on: :member
      post :send_simple_test_email, on: :member
    end
    
    resources :email_metrics, only: [:index]
    
    resources :news_sources do
      member do
        post :validate, defaults: { format: :json }
        patch :validate, defaults: { format: :json }
        get :preview
      end
      collection do
        post :validate_new, defaults: { format: :json }
      end
    end
  end
end
