############################################################
# Events
############################################################

resources :events, only: [:index, :show, :destroy] do
  patch :review_event, on: :member
end