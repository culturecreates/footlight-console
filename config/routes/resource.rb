  ############################################################
  # Resource URI tools
  ############################################################

  # NOTE: singular because controller name is ResourceController
  resources :resource do
    collection do
      patch  :refresh_uri
      delete :delete_uri
    end
  end