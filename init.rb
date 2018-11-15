require 'redmine'

RISKS_VERSION_NUMBER = '1.0.0'

Redmine::Plugin.register :redmine_risks do
  name 'Risks'
  author 'eXolnet'
  description 'Manage the results of the qualitative risk analysis, quantitative risk analysis, and risk response planning.'
  version RISKS_VERSION_NUMBER
  url 'https://github.com/eXolnet/redmine-risks'
  author_url 'https://www.exolnet.com'

  requires_redmine :version_or_higher => '3.4'

  menu :project_menu, :risks, { :controller => 'risks', :action => 'index' }, :caption => :label_risks, :before => :settings, :param => :project_id

  project_module :risks do
    permission :view_risks,            { :risks => [:index, :show] }, :read => true
    permission :add_risks,             { :risks => [:new, :create, :commit] }
    permission :edit_risks,            { :risks => [:edit, :update] }
    permission :delete_risks,          { :risks => [:destroy] }, :require => :member

    # Related issues
    permission :manage_risk_relations, {}
  end
end

require 'redmine_risks'
