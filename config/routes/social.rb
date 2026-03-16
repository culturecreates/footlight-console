  ############################################################
  # Social features
  ############################################################

  resources :microposts,    only: [:create, :destroy, :new, :index]
  resources :relationships, only: [:create, :destroy]