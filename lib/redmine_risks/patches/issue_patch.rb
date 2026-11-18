require_dependency 'issue'

module RedmineRisks
  module Patches
    module IssuePatch
      def self.included(base) # :nodoc:
        base.send(:include, InstanceMethods)

        base.class_eval do
          has_and_belongs_to_many :risks, :join_table => 'risk_issues'
        end
      end

      module InstanceMethods
        # Returns the risks linked to the issue that the user is allowed to view
        def visible_risks(user = User.current)
          risks.
            joins(:project).
            where(Project.allowed_to_condition(user, :view_risks)).
            preload(:project, :assigned_to).
            reorder(:id)
        end
      end
    end
  end
end

unless Issue.included_modules.include?(RedmineRisks::Patches::IssuePatch)
  Issue.send(:include, RedmineRisks::Patches::IssuePatch)
end
