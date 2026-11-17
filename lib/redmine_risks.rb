require File.dirname(__FILE__) + '/redmine_risks/patches/application_helper_patch'
require File.dirname(__FILE__) + '/redmine_risks/patches/journal_patch'

# Force load the subclasses in development mode
require_dependency File.dirname(__FILE__) + '/../app/models/risk_category'

module RedmineRisks
  class << self
    #
  end
end
