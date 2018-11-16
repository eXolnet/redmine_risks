require 'redmine_risks/patches/application_helper_patch'
require 'redmine_risks/patches/journal_patch'

# Force load the subclasses in development mode
require_dependency 'risk_category'

module RedmineRisks
  class << self
    #
  end
end
