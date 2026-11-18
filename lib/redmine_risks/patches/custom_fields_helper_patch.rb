require_dependency 'custom_fields_helper'

module RedmineRisks
  module Patches
    module CustomFieldsHelperPatch
      RISK_CUSTOM_FIELDS_TAB = {
        :name => 'RiskCustomField',
        :partial => 'custom_fields/index',
        :label => :label_risk_plural
      }.freeze

      def self.apply
        tabs = CustomFieldsHelper::CUSTOM_FIELDS_TABS
        tabs << RISK_CUSTOM_FIELDS_TAB unless tabs.any? {|tab| tab[:name] == RISK_CUSTOM_FIELDS_TAB[:name]}
      end
    end
  end
end

RedmineRisks::Patches::CustomFieldsHelperPatch.apply
