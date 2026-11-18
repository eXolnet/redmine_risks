require File.expand_path('../../test_helper', __FILE__)

class RiskCustomFieldsControllerTest < Redmine::ControllerTest
  tests CustomFieldsController

  fixtures :users, :roles

  def setup
    @request.session[:user_id] = 1 # admin
  end

  def test_index_should_display_the_risks_tab
    RiskCustomField.create!(:name => 'Owner team', :field_format => 'string')

    get :index

    assert_response :success
    assert_select '#tab-RiskCustomField', :text => ::I18n.t(:label_risk_plural)
    assert_select '#tab-content-RiskCustomField td.name', :text => 'Owner team'
  end

  def test_new_should_offer_the_risk_type
    get :new

    assert_response :success
    assert_select 'input[type=radio][name=type][value=RiskCustomField]'
  end

  def test_new_risk_custom_field_should_display_filter_and_role_visibility_options
    get :new, :params => {:type => 'RiskCustomField'}

    assert_response :success
    assert_select 'form#custom_field_form' do
      assert_select 'input[name=type][value=RiskCustomField]'
      assert_select 'input[type=checkbox][name=?]', 'custom_field[is_required]'
      assert_select 'input[type=checkbox][name=?]', 'custom_field[is_filter]'
      assert_select 'input[type=radio][name=?]', 'custom_field[visible]', 2
      assert_select 'input[type=checkbox][name=?]', 'custom_field[role_ids][]', Role.givable.count
    end
  end

  def test_create_risk_custom_field
    assert_difference 'RiskCustomField.count' do
      post :create, :params => {
        :type => 'RiskCustomField',
        :custom_field => {:name => 'Owner team', :field_format => 'string', :is_filter => '1',
                          :visible => '0', :role_ids => ['1', '']}
      }
    end

    field = RiskCustomField.order(:id).last
    assert_redirected_to '/custom_fields?tab=RiskCustomField'
    assert field.is_filter?
    assert_not field.visible?
    assert_equal [1], field.role_ids
  end
end
