require 'redmine'

RISKS_VERSION_NUMBER = '1.4.1'

Redmine::Plugin.register :redmine_risks do
  name 'Risks'
  author 'eXolnet'
  description 'Manage the results of the qualitative risk analysis, quantitative risk analysis, and risk response planning.'
  version RISKS_VERSION_NUMBER
  url 'https://github.com/eXolnet/redmine_risks'
  author_url 'https://www.exolnet.com'

  requires_redmine :version_or_higher => '3.4'

  menu :project_menu, :risks, { :controller => 'risks', :action => 'index' }, :caption => :label_risks, :before => :settings, :param => :project_id
  menu :project_menu, :new_risk, { :controller => 'risks', :action => 'new' }, :caption => :label_new_risk, :after => :new_wiki_sub, :param => :project_id, :parent => :new_object

  project_module :risks do
    permission :view_risks,            { :risks => [:index, :show] }, :read => true
    permission :add_risks,             { :risks => [:new, :create, :commit] }
    permission :edit_risks,            { :risks => [:edit, :update] }
    permission :delete_risks,          { :risks => [:destroy] }, :require => :member

    # Related issues
    permission :manage_risk_relations, {}
  end

  # Pulls are added to the activity view
  activity_provider :risks, :class_name => ['Risk', 'Journal']
end

require File.dirname(__FILE__) + '/lib/redmine_risks'
