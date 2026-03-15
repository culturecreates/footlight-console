  ############################################################
  # Users
  ############################################################

  resources :users do
    member do
      get :following
      get :followers
      get :license
    end
  end