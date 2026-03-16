  ############################################################
  # Linked Data tools
  ############################################################

  scope "/linked_data", controller: :linked_data do
    get :linker
    get :new_resource
    patch :add_linked_data
    patch :remove_linked_data
    post :create_resource
  end