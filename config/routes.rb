Rails.application.routes.draw do
  resources :repos
  mount RailsAdmin::Engine => '/admin_repo', as: 'rails_admin'
  root to: "catalog#index"
  blacklight_for :catalog
  devise_for :users
  mount Qa::Engine => '/qa'
  mount HydraEditor::Engine => '/'
end
