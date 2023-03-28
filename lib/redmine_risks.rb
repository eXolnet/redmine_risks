require 'redmine_risks/patches/application_helper_patch'
require 'redmine_risks/patches/auto_completes_controller_patch'
require 'redmine_risks/patches/context_menus_controller_patch'
require 'redmine_risks/patches/journal_patch'
require 'redmine_risks/patches/issue_patch'
# Force load the subclasses in development mode
require_dependency 'risk_category'

module RedmineRisks
  class << self
    #
    IssuesController.send :helper, RisksHelper
  end
end
