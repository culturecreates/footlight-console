  ############################################################
  # Authentication
  ############################################################

  get  'signup', to: 'users#new'

  get    'login',  to: 'sessions#new'
  post   'login',  to: 'sessions#create'
  delete 'logout', to: 'sessions#destroy'