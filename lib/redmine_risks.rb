require File.dirname(__FILE__) + '/redmine_risks/patches/application_helper_patch'
require File.dirname(__FILE__) + '/redmine_risks/patches/journal_patch'
require File.dirname(__FILE__) + '/redmine_risks/patches/issue_patch'
require File.dirname(__FILE__) + '/redmine_risks/patches/custom_fields_helper_patch'
require File.dirname(__FILE__) + '/redmine_risks/hooks/views_issues_hook'
require File.dirname(__FILE__) + '/redmine_risks/hooks/views_custom_fields_hook'

# Force load the subclasses in development mode
require_dependency File.dirname(__FILE__) + '/../app/models/risk_category'
require_dependency File.dirname(__FILE__) + '/../app/models/risk_custom_field'

module RedmineRisks
  class << self
    #
  end
end
