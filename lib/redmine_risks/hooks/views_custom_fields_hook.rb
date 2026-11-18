module RedmineRisks
  module Hooks
    # The core custom field form only shows the filter checkbox and the role
    # visibility selector for core custom field types.
    class ViewsCustomFieldsHook < Redmine::Hook::ViewListener
      render_on :view_custom_fields_form_risk_custom_field, :partial => 'custom_fields/risk_custom_field_options'
    end
  end
end
