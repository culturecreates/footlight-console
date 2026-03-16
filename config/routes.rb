Rails.application.routes.draw do

  ############################################################
  # Helper to load modular route files
  ############################################################

  route_loader = ->(name) {
    instance_eval(File.read(Rails.root.join("config/routes/#{name}.rb")))
  }

  ############################################################
  # Root / Static pages
  ############################################################

  root 'static_pages#dashboard'

  get 'dashboard', to: 'static_pages#dashboard'
  get 'about',     to: 'static_pages#about'
  get 'contact',   to: 'static_pages#contact'
  get 'export',    to: 'static_pages#export'
  get 'graph',     to: 'static_pages#graph'

  ############################################################
  # Modular route sections
  ############################################################

  route_loader.call(:auth)
  route_loader.call(:users)
  route_loader.call(:auth_helpers)
  route_loader.call(:social)
  route_loader.call(:linked_data)
  route_loader.call(:resource)
  route_loader.call(:events)
  route_loader.call(:statements)
  route_loader.call(:websites)
  route_loader.call(:sources)
  route_loader.call(:reconciliation)

  ############################################################
  # Catch-all route (must remain last)
  ############################################################

  match '*path', to: 'application#route_not_found', via: :all

end