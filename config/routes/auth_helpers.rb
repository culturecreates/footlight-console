  ############################################################
  # Authentication helpers
  ############################################################

  resources :account_activations, only: [:edit]
  resources :password_resets,     only: [:new, :create, :edit, :update]