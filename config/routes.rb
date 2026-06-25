Rails.application.routes.draw do
  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
  get "offline" => "pwa#offline", as: :offline

  root "employee/dashboard#show"

  get "clockings" => "employee/clockings#index", as: :clockings
  post "clock-in" => "employee/clockings#clock_in", as: :clock_in
  post "clock-out" => "employee/clockings#clock_out", as: :clock_out

  resources :corrections, controller: "employee/corrections", only: %i[index new create]
  resource :account, controller: "employee/accounts", only: %i[show update]

  namespace :admin do
    root "dashboard#index"

    resources :employees, only: %i[index new create edit update]
    resource :import, controller: "imports", only: %i[new create]
    resources :reports, only: %i[index]

    resources :corrections, only: %i[index] do
      member do
        post :approve
        post :reject
      end
    end
  end
end
