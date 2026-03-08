Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/*
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest

  namespace :api do
    namespace :v1 do
      resources :monitors do
        post :run, on: :member
        get :runs, on: :member
      end
      resources :runs, only: :show do
        get :diff, on: :member
      end
      resources :incidents, only: %i[index show update]
      get :metrics, to: "metrics#index"
      get :health, to: "health#show"
    end
  end

  # Defines the root path route ("/")
  # root "posts#index"
end
