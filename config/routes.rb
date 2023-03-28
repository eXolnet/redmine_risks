# Plugin's routes
# See: http://guides.rubyonrails.org/routing.html

match '/risks/preview/new/:project_id', :to => 'risks#preview', :as => 'preview_new_risk', :via => [:get, :post, :put, :patch]
match '/risks/preview/edit/:id', :to => 'risks#preview', :as => 'preview_edit_risk', :via => [:get, :post, :put, :patch]
post '/risks/:id/quoted', :to => 'risks#quoted', :id => /\d+/, :as => 'quoted_risk'

match '/risks/context_menu', :to => 'context_menus#risks', :as => 'risks_context_menu', :via => [:get, :post]
match 'auto_completes/risks' => 'auto_completes#risks', via: :get, as: 'auto_complete_risks'

resources :projects do
  resources :risks, :only => [:index, :new, :create]
end

resources :risks, :except => [:index, :new, :create] do
  post   'issues', :to => 'risk_issues#create_by_risk'
  delete 'issues/:issue_id', :to => 'risk_issues#destroy_by_risk'

  collection do
    post 'bulk_update'
  end
end

resources :issues, :except => [:index, :new, :create] do
  post   'risks', :to => 'risk_issues#create_by_issue'
  delete 'risks/:risk_id', :to => 'risk_issues#destroy_by_issue'

  collection do
    post 'bulk_update'
  end
end

match '/risks', :controller => 'risks', :action => 'destroy', :via => :delete
