require_dependency 'journal'

module RedmineRisks
  module Patches
    module JournalPatch
      def self.included(base) # :nodoc:
        base.send(:prepend, InstanceMethods)

        base.class_eval do
          belongs_to :risk, :foreign_key => :journalized_id

          # Journal.visible checks the visibility of the journalized issue, so the
          # visibility of risk journals is checked with the view_risks permission
          # on the risk's project instead.
          acts_as_activity_provider :type => 'risks',
                                    :author_key => :user_id,
                                    :permission => :view_risks,
                                    :scope => proc {
                                      preload({:risk => :project}, :user).
                                        joins(:risk => :project).
                                        where(:journalized_type => 'Risk').
                                        where("#{Journal.table_name}.notes <> ''").
                                        where(Journal.visible_notes_condition(User.current, :skip_pre_condition => true))
                                    }

        end
      end

      module InstanceMethods
        def event_title
          return super unless risk_journal?

          "#{::I18n.t(:label_risk)} ##{risk.id}: #{risk.subject}"
        end

        def event_type
          return super unless risk_journal?

          'risk'
        end

        def event_group
          return super unless risk_journal?

          risk
        end

        def event_url(options = {})
          return super unless risk_journal?

          {:controller => 'risks', :action => 'show', :id => risk.id, :anchor => "change-#{id}"}.merge(options)
        end

        private

        def risk_journal?
          journalized_type == 'Risk'
        end
      end
    end
  end
end

unless Journal.included_modules.include?(RedmineRisks::Patches::JournalPatch)
  Journal.send(:include, RedmineRisks::Patches::JournalPatch)
end
