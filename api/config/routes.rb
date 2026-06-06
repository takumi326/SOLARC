Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  namespace :api do
    get "auth/me", to: "auth#me"
    delete "auth/logout", to: "auth#logout"

    get "categories/majors", to: "categories#majors"
    get "categories/minors", to: "categories#minors"
    post "categories/majors", to: "categories#create_major"
    post "categories/minors", to: "categories#create_minor"
    patch "categories/majors/:id", to: "categories#update_major"
    patch "categories/minors/:id", to: "categories#update_minor"
    delete "categories/majors/:id", to: "categories#destroy_major"
    delete "categories/minors/:id", to: "categories#destroy_minor"

    resources :payment_methods, only: [ :index, :create, :update, :destroy ]
    resources :expenses, only: [ :index, :create, :update, :destroy ] do
      member do
        get :actuals
        post "actuals/bulk_from_month", action: :bulk_update_actuals_from_month
        patch "actuals/:transaction_id", action: :update_actual
        delete "actuals/:transaction_id", action: :destroy_actual
      end
    end
    resources :incomes, only: [ :index, :create, :update, :destroy ] do
      member do
        get :actuals
        post "actuals/bulk_from_month", action: :bulk_update_actuals_from_month
        patch "actuals/:transaction_id", action: :update_actual
        delete "actuals/:transaction_id", action: :destroy_actual
      end
    end

    resources :forecasts, only: [ :index ] do
      collection do
        post :upsert
        post :fill_missing
      end
    end

    get "forecast_defaults", to: "forecast_defaults#show"
    patch "forecast_defaults", to: "forecast_defaults#update"

    post "actuals/sync", to: "actuals#sync"
    get "dashboard", to: "dashboard#show"
    get "dashboard/fiscal_actuals", to: "dashboard#fiscal_actuals"
    delete "session", to: "sessions#destroy"

    resources :monthly_balances, only: [ :index ] do
      collection do
        post :upsert
      end
    end

    resources :stock_daily_notes, only: [ :index, :destroy ] do
      collection do
        post :upsert
      end
    end

    resources :industries, only: [ :index ]

    post "stocks/import", to: "stocks#import"
    resources :stocks, only: [ :index, :show, :update ] do
      member do
        get :timeline
      end
      resources :stock_notes, only: [ :index, :create, :update, :destroy ]
    end

    resources :entries, only: [ :show, :create, :update, :destroy ]
    resources :exits, controller: "stock_exits", only: [ :show, :create, :update, :destroy ]
    resources :line_changes, only: [ :show, :create, :update, :destroy ]

    get "stock_trade_events", to: "stock_trade_events#index"
  end

  # Defines the root path route ("/")
  # root "posts#index"
end
