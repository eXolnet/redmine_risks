require_dependency 'journal'

module RedmineRisks
  module Patches
    module JournalPatch
      def self.included(base) # :nodoc:
        base.send(:include, InstanceMethods)

        base.class_eval do
          unloadable # Send unloadable so it will not be unloaded in development

          belongs_to :risk, :foreign_key => :journalized_id

          acts_as_activity_provider :type => 'risks',
                                    :author_key => :user_id,
                                    :scope => preload({:issue => :project}, :user).
                                      joins("LEFT OUTER JOIN #{JournalDetail.table_name} ON #{JournalDetail.table_name}.journal_id = #{Journal.table_name}.id").
                                      where("#{Journal.table_name}.journalized_type = 'Risk' AND" +
                                              " (#{Journal.table_name}.notes <> '')").distinct

        end
      end

      module InstanceMethods
        #
      end
    end
  end
end

unless Journal.included_modules.include?(RedmineRisks::Patches::JournalPatch)
  Journal.send(:include, RedmineRisks::Patches::JournalPatch)
end
