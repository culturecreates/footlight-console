  ############################################################
  # Websites (scraping sources)
  ############################################################

  resources :websites do
    collection do
      get :first_scrape
      get :closed_beta
    end
  end