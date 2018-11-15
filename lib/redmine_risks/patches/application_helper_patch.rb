require_dependency 'application_helper'

module RedmineRisks
  module Patches
    module ApplicationHelperPatch
      def self.included(base) # :nodoc:
        base.send(:include, InstanceMethods)

        base.class_eval do
          unloadable # Send unloadable so it will not be unloaded in development
        end
      end

      module InstanceMethods
        def link_to_risk(risk, options={})
          text = options.delete(:text) || risk.summary

          link_to(h(text), {:controller => 'risks', :action => 'show', :id => risk}, :title => text)
        end
      end
    end
  end
end

unless ApplicationHelper.included_modules.include?(RedmineRisks::Patches::ApplicationHelperPatch)
  ApplicationHelper.send(:include, RedmineRisks::Patches::ApplicationHelperPatch)
end
