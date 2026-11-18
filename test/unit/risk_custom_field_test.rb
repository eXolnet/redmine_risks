require File.expand_path('../../test_helper', __FILE__)

class RiskCustomFieldTest < ActiveSupport::TestCase
  fixtures :projects, :users, :email_addresses, :roles, :members, :member_roles,
           :enabled_modules, :risks

  RISK_PERMISSIONS = [:view_risks, :add_risks, :edit_risks]

  def setup
    User.current = nil
    EnabledModule.create!(:project_id => 1, :name => 'risks')
    Role.find(1).add_permission!(*RISK_PERMISSIONS)
    Role.find(2).add_permission!(*RISK_PERMISSIONS)
  end

  def teardown
    User.current = nil
  end

  def test_type_name
    assert_equal :label_risk_plural, RiskCustomField.new.type_name
  end

  def test_customized_class_should_be_risk
    assert_equal Risk, RiskCustomField.customized_class
  end

  def test_new_subclass_instance_should_build_a_risk_custom_field
    assert_kind_of RiskCustomField, CustomField.new_subclass_instance('RiskCustomField')
  end

  def test_risk_custom_fields_tab_should_be_registered
    tab = CustomFieldsHelper::CUSTOM_FIELDS_TABS.detect {|t| t[:name] == 'RiskCustomField'}

    assert_not_nil tab
    assert_equal :label_risk_plural, tab[:label]
    assert_equal 1, CustomFieldsHelper::CUSTOM_FIELDS_TABS.count {|t| t[:name] == 'RiskCustomField'}
  end

  def test_visible_field_should_be_visible_by_anyone
    field = RiskCustomField.create!(:name => 'Public', :field_format => 'string', :visible => true)

    assert field.visible_by?(Project.find(1), User.find(3))
  end

  def test_field_restricted_to_roles_should_only_be_visible_by_members_with_those_roles
    field = RiskCustomField.create!(:name => 'Managers only', :field_format => 'string', :visible => false, :role_ids => [1])
    project = Project.find(1)

    assert field.visible_by?(project, User.find(2)) # jsmith is Manager
    assert_not field.visible_by?(project, User.find(3)) # dlopper is Developer
    assert field.visible_by?(project, User.find(1)) # admin
  end

  def test_field_not_visible_without_roles_should_be_invalid
    field = RiskCustomField.new(:name => 'Hidden', :field_format => 'string', :visible => false)

    assert_not field.save
    assert_include "#{::I18n.t(:label_role_plural)} #{::I18n.t('activerecord.errors.messages.blank')}", field.errors.full_messages
  end

  def test_available_custom_fields_should_return_risk_custom_fields_only
    risk_field = RiskCustomField.create!(:name => 'Risk field', :field_format => 'string')
    other_field = VersionCustomField.create!(:name => 'Version field', :field_format => 'string')

    fields = Risk.new.available_custom_fields

    assert_include risk_field, fields
    assert_not_include other_field, fields
  end
end
