# Plugin's routes
# See: http://guides.rubyonrails.org/routing.html

match '/risks/preview/new/:project_id', :to => 'risks#preview', :as => 'preview_new_risk', :via => [:get, :post, :put, :patch]
match '/risks/preview/edit/:id', :to => 'risks#preview', :as => 'preview_edit_risk', :via => [:get, :post, :put, :patch]
post '/risks/:id/quoted', :to => 'risks#quoted', :id => /\d+/, :as => 'quoted_risk'

match '/risks/context_menu', :to => 'risk_context_menus#index', :as => 'risks_context_menu', :via => [:get, :post]

resources :projects do
  resources :risks, :only => [:index, :new, :create]
end

resources :risks, :except => [:index, :new, :create] do
  post   'issues', :to => 'risk_issues#create'
  delete 'issues/:issue_id', :to => 'risk_issues#destroy'

  collection do
    match 'bulk_edit', :via => [:get, :post]
    post 'bulk_update'
  end
end

match '/risks', :controller => 'risks', :action => 'destroy', :via => :delete

post   '/issues/:issue_id/risks', :to => 'issue_risks#create', :issue_id => /\d+/, :as => 'issue_risks'
delete '/issues/:issue_id/risks/:risk_id', :to => 'issue_risks#destroy', :issue_id => /\d+/, :risk_id => /\d+/, :as => 'issue_risk'
