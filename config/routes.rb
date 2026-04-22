Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", :as => :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # NOTA: sessions usa route overrides (to:) — dívida técnica herdada da Fase 2.
  # Proibido pela regra 4 de CLAUDE.base.md; manter por enquanto para evitar
  # colisão com `root` sem reescrever Phase 2. Revisar quando houver janela.
  get "/login", to: "sessions#new", as: :login
  post "/session", to: "sessions#create", as: :session
  delete "/logout", to: "sessions#destroy", as: :logout

  resources :airports, only: %i[index]
  resources :searches, only: %i[new create]

  root "searches#new"
end
