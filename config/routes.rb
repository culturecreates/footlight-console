Rails.application.routes.draw do
  get 'sources/index'

  get 'sources/show'

  get 'linked_data/linker'
  get 'linked_data/new_resource'
  patch 'linked_data/add_linked_data'
  patch 'linked_data/remove_linked_data'
  post 'linked_data/create_resource'
 

  root   'static_pages#dashboard'
  get    '/dashboard', to: 'static_pages#dashboard'
  get    '/about',   to: 'static_pages#about'
  get    '/contact', to: 'static_pages#contact'

  get    '/export', to: 'static_pages#export'
  get    '/graph',   to: 'static_pages#graph'



  get    '/signup',  to: 'users#new'
  get    '/login',   to: 'sessions#new'
  post   '/login',   to: 'sessions#create'
  delete '/logout',  to: 'sessions#destroy'

  resources :users do
    member do
      get :following, :followers, :license
    end
  end

  resources :resource do
    collection do
        patch 'refresh_uri'
        delete 'delete_uri'
    end
  end

  resources :account_activations, only: [:edit]
  resources :password_resets,     only: [:new, :create, :edit, :update]
  resources :microposts,          only: [:create, :destroy, :new, :index]
  resources :relationships,       only: [:create, :destroy]

  get '/events', to: "events#index", as: :events


  get '/events/:id', to: "events#show", as: :event

  patch '/events/:event_id/review_event',
      to: "events#review_event",
      as: :review_all_event

  delete '/events/:event_id',
      to: "events#destroy",
      as: :destroy_event


  patch '/statements/:id/review_statement',
      to: "statements#review_statement",
      as: :review_statement

  get '/statements/edit_manual_statement',
      to: "statements#edit_manual_statement",
      as: :edit_manual_statement
     
  get '/statements/cancel_edit_manual_statement',
      to: "statements#cancel_edit_manual_statement",
      as: :cancel_edit_manual_statement

  patch '/statements/:id/save_manual_statement',
      to: "statements#save_manual_statement",
      as: :save_manual_statement

  patch '/statements/:id/flag_statement',
      to: "statements#flag_statement",
      as: :flag_statement_patch

  get '/statements/:id/flag_statement',
      to: "statements#flag_statement",
      as: :flag_statement

  get '/statements/:id/activate',
      to: "statements#activate",
      as: :activate_statement

  get '/statements/:id/activate_individual',
      to: "statements#activate_individual",
      as: :activate_individual_statement

  get '/statements/:id/deactivate_individual',
      to: "statements#deactivate_individual",
      as: :deactivate_individual_statement

  get '/statements/:id/reconnect_feed',
      to: "statements#reconnect_feed",
      as: :reconnect_feed_statement

  resources :websites do
    collection do
      get 'first_scrape', 'closed_beta'
    end
  end

  resources :sources do
    collection do
        get 'source_id'
    end
  end

  resources :reconciliation, only: [:index]
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html
end
