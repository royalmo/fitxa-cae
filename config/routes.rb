Rails.application.routes.draw do
  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
  get "unavailable" => "pwa#unavailable", as: :unavailable

  match "400" => "errors#bad_request", via: :all
  match "404" => "errors#not_found", via: :all
  match "406" => "errors#not_acceptable", via: :all
  match "422" => "errors#unprocessable_entity", via: :all
  match "500" => "errors#internal_server_error", via: :all

  if Rails.env.development? || Rails.env.test?
    match "errors/400" => "errors#bad_request", via: :all
    match "errors/404" => "errors#not_found", via: :all
    match "errors/406" => "errors#not_acceptable", via: :all
    match "errors/422" => "errors#unprocessable_entity", via: :all
    match "errors/500" => "errors#internal_server_error", via: :all
    match "admin/400" => "errors#bad_request", via: :all
    match "admin/404" => "errors#not_found", via: :all
    match "admin/406" => "errors#not_acceptable", via: :all
    match "admin/422" => "errors#unprocessable_entity", via: :all
    match "admin/500" => "errors#internal_server_error", via: :all
  end

  get "login" => "employee/sessions#new", as: :login
  post "login" => "employee/sessions#create"
  post "login/code" => "employee/sessions#request_code", as: :request_login_code
  get "login/code" => "employee/sessions#code", as: :login_code
  post "login/code/verify" => "employee/sessions#verify_code", as: :verify_login_code
  delete "logout" => "employee/sessions#destroy", as: :logout

  root "employee/dashboard#show"

  get "clockings" => "employee/clockings#index", as: :clockings
  post "clock-in" => "employee/clockings#clock_in", as: :clock_in
  post "clock-out" => "employee/clockings#clock_out", as: :clock_out

  resources :corrections, controller: "employee/corrections", only: %i[index show new create destroy] do
    get :day, on: :collection
    post :restore, on: :member
  end
  resource :account, controller: "employee/accounts", only: :show
  patch "account/contact" => "employee/accounts#update_contact", as: :account_contact
  patch "account/password" => "employee/accounts#update_password", as: :account_password
  post "account/human-resources-contact" => "employee/accounts#contact_human_resources",
    as: :account_human_resources_contact

  namespace :admin do
    get "login" => "sessions#new", as: :login
    post "login" => "sessions#create"
    delete "logout" => "sessions#destroy", as: :logout

    root "dashboard#index"
    get "dashboard/statistics" => "dashboard#statistics", as: :dashboard_statistics

    resource :account, controller: "accounts", only: %i[show]
    patch "account/profile" => "accounts#update_profile", as: :account_profile
    patch "account/password" => "accounts#update_password", as: :account_password
    get "employee-search" => "employee_search#index", as: :employee_search
    get "tag-search" => "tag_search#index", as: :tag_search
    get "audit-author-search" => "audit_author_search#index", as: :audit_author_search
    get "audit-kind-search" => "audit_kind_search#index", as: :audit_kind_search
    resources :employees, only: %i[index new create edit update] do
      patch :activation, on: :member

      collection do
        get "bulk/activation" => "employee_bulk_actions#activation", as: :bulk_activation
        post "bulk/activation/simulate" => "employee_bulk_actions#simulate_activation", as: :simulate_bulk_activation
        post "bulk/activation/run" => "employee_bulk_actions#run_activation", as: :run_bulk_activation
        get "bulk/tags" => "employee_bulk_actions#tags", as: :bulk_tags
        post "bulk/tags/simulate" => "employee_bulk_actions#simulate_tags", as: :simulate_bulk_tags
        post "bulk/tags/run" => "employee_bulk_actions#run_tags", as: :run_bulk_tags
      end
    end
    resource :import, controller: "imports", only: %i[new create] do
      post :simulate
    end
    resources :swipes, only: %i[index]
    resources :calendars, only: %i[index]
    resources :tags, only: %i[index create update] do
      patch :activation, on: :member
    end
    resources :audit_actions, path: "activity", only: %i[index] do
      get :export, on: :collection
    end
    resources :managers, only: %i[index new create edit update] do
      patch :activation, on: :member
    end
    resources :reports, only: %i[index]

    resources :corrections, only: %i[index show new create edit update] do
      get :day, on: :collection

      member do
        post :approve
        post :reject
      end
    end
  end
end
