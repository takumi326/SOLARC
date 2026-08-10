Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  root "finance_summaries#show"

  get "login", to: "sessions#new"
  delete "logout", to: "sessions#destroy"
  get "/auth/failure", to: "sessions#failure"
  match "/auth/:provider/callback", to: "sessions#create", via: [ :get, :post ]

  get "finance", to: "finance_summaries#show", as: :finance_summary
  post "finance/sync_recurring", to: "finance_summaries#sync_recurring", as: :finance_sync_recurring
  post "finance/sync_one_time", to: "finance_summaries#sync_one_time", as: :finance_sync_one_time
  get "finance/expense_breakdown", to: "finance_summaries#expense_breakdown", as: :finance_expense_breakdown
  get "finance/forecasts/edit", to: "finance_summaries#edit_forecast", as: :edit_finance_forecast
  patch "finance/forecasts", to: "finance_summaries#update_forecast", as: :finance_forecast
  get "finance/forecasts/bulk/edit", to: "finance_summaries#bulk_forecasts_form", as: :edit_finance_bulk_forecasts
  post "finance/bulk_forecasts", to: "finance_summaries#bulk_forecasts", as: :finance_bulk_forecasts
  post "finance/monthly_balance", to: "finance_summaries#monthly_balance", as: :finance_monthly_balance

  get "finance/import", to: "finance_imports#show", as: :finance_import
  post "finance/import", to: "finance_imports#create"
  post "finance/import/append", to: "finance_imports#append", as: :append_finance_import
  post "finance/import/commit", to: "finance_imports#commit", as: :commit_finance_import

  get "finance/settings", to: "settings#show", as: :finance_settings
  patch "finance/settings", to: "settings#update"

  namespace :finance do
    resources :one_time_expenses, only: [ :new, :create ]
    get "masters", to: "masters#show", as: :masters

    namespace :masters do
      resources :major_categories, except: [ :show ]
      resources :minor_categories, except: [ :show ]
      resources :payment_methods, except: [ :show ]
      resources :expenses, except: [ :show ]
      resources :incomes, except: [ :show ]
    end

    resources :expenses, only: [] do
      resources :actuals, controller: "/expense_actuals", only: [ :index, :edit, :update, :destroy ] do
        collection do
          post :bulk_from_month
        end
      end
    end

    resources :incomes, only: [] do
      resources :actuals, controller: "/income_actuals", only: [ :index, :edit, :update, :destroy ] do
        collection do
          post :bulk_from_month
        end
      end
    end
  end

  get "stocks/daily/detail", to: "stock_daily_notes#show", as: :stock_daily_note_detail
  get "stocks/daily/prompts", to: "stock_daily_notes#edit_prompts", as: :edit_stock_daily_prompts
  patch "stocks/daily/prompts", to: "stock_daily_notes#update_prompts", as: :stock_daily_prompts
  get "stocks/daily", to: "stock_daily_notes#index", as: :stock_daily_notes
  get "stock_daily_notes/new", to: "stock_daily_notes#new", as: :new_stock_daily_note
  post "stock_daily_notes", to: "stock_daily_notes#create", as: :stock_daily_notes_create
  get "stock_daily_notes/edit", to: "stock_daily_notes#edit", as: :edit_stock_daily_note
  patch "stock_daily_notes", to: "stock_daily_notes#update", as: :stock_daily_note
  delete "stock_daily_notes/:id", to: "stock_daily_notes#destroy", as: :destroy_stock_daily_note

  get "stocks/trades/:mode", to: "stock_trades#index", as: :stock_trades,
      constraints: { mode: /real|virtual-human|virtual-ai/ }

  scope "stocks" do
    resources :industries, only: [ :index, :create ]
    resources :ai_scripts, path: "ai-scripts", only: [ :index, :new, :create, :edit, :update, :destroy ]
    resources :stock_trade_rules, path: "trade-rules"
  end

  post "stocks/import", to: "stocks#import", as: :import_stocks
  resources :stocks, only: [ :index, :show, :edit, :update ] do
    member do
      get :timeline
    end
    resources :stock_notes, only: [ :new, :create, :edit, :update, :destroy ]
  end

  resources :entries, only: [ :new, :create, :show, :edit, :update, :destroy ]
  resources :exits, controller: "stock_exits", only: [ :new, :create, :show, :edit, :update, :destroy ]
  resources :line_changes, only: [ :new, :create, :show, :edit, :update, :destroy ]
end
