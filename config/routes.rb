# frozen_string_literal: true

Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  root "home#index"

  resource :registration, only: %i[new create]
  resource :session, only: %i[new create destroy]
  resources :passwords, param: :token, only: %i[new create edit update]

  resources :rooms, only: %i[index show new create] do
    member do
      get :player_panel
      get :archive
      post :start
      post :next_round
      post :remove_player
      post :play
      post :suit
      post :ace_tail_draw
      post :ace_pass
      post :optional_draw
      post :turn_pass
      post :seven_take
      post :create_invite
    end
  end

  get "join/:token", to: "room_joins#show", as: :room_join
  post "join/:token", to: "room_joins#create"
end
