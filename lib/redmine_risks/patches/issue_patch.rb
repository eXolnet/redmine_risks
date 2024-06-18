module RedmineRisks
  module Patches
    module IssuePatch
      def self.included(base)
        base.class_eval do
          has_and_belongs_to_many :risks, :join_table => 'risk_issues'
        end
      end
    end
  end
end

Issue.send(:include, RedmineRisks::Patches::IssuePatch)