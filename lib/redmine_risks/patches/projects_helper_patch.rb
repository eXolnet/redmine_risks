require_dependency 'projects_helper'

module RedmineRisks
  module Patches
    module ProjectsHelperPatch
      # Adds the "Risks" tab (project risk categories) to the project settings
      def project_settings_tabs
        tabs = super
        tab = {
          :name => 'risks',
          :action => :manage_project_risk_categories,
          :partial => 'projects/settings/risk_categories',
          :label => :label_risks
        }
        if User.current.allowed_to?(tab[:action], @project) && @project.module_enabled?(:risks)
          tabs << tab
        end
        tabs
      end
    end
  end
end

unless ProjectsHelper.ancestors.include?(RedmineRisks::Patches::ProjectsHelperPatch)
  ProjectsHelper.prepend(RedmineRisks::Patches::ProjectsHelperPatch)
end
