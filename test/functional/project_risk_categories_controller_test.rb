require File.expand_path('../../test_helper', __FILE__)

class ProjectRiskCategoriesControllerTest < ActionController::TestCase
  fixtures :projects,
           :users,
           :email_addresses,
           :roles,
           :members,
           :member_roles,
           :enabled_modules,
           :enumerations,
           :trackers,
           :projects_trackers,
           :issue_statuses,
           :issues,
           :risks,
           :risk_issues

  def setup
    @project = Project.find(1)
    EnabledModule.create!(:project => @project, :name => 'risks')
    @role = Role.find(1)
    @role.add_permission!(:manage_project_risk_categories)

    @technical = RiskCategory.create!(:name => 'Technical', :position => 1)
    @financial = RiskCategory.create!(:name => 'Financial', :position => 2)
    Risk.where(:id => [1, 2]).update_all(:category_id => @technical.id)

    # jsmith, Manager on eCookbook
    @request.session[:user_id] = 2
  end

  def test_put_update_should_create_project_override
    assert_difference 'RiskCategory.count' do
      compatible_request :put, :update, :project_id => 'ecookbook', :enumerations => {
        @technical.id.to_s => {:parent_id => @technical.id.to_s, :active => '0'},
        @financial.id.to_s => {:parent_id => @financial.id.to_s, :active => '1'}
      }
    end

    assert_redirected_to '/projects/ecookbook/settings/risks'
    override = @project.risk_categories.first
    assert_equal @technical, override.parent
    assert_not override.active?
    assert_equal [@financial], @project.risk_categories_available.to_a
  end

  def test_put_update_should_update_existing_override
    override = @project.risk_categories.create!(:name => 'Technical', :parent => @technical, :active => false)

    compatible_request :put, :update, :project_id => 'ecookbook', :enumerations => {
      override.id.to_s => {:active => '1'}
    }

    assert_redirected_to '/projects/ecookbook/settings/risks'
    assert override.reload.active?
  end

  def test_delete_destroy_should_reset_overrides_and_restore_risks
    compatible_request :put, :update, :project_id => 'ecookbook', :enumerations => {
      @technical.id.to_s => {:parent_id => @technical.id.to_s, :active => '0'}
    }
    assert_equal 1, @project.risk_categories.count

    compatible_request :delete, :destroy, :project_id => 'ecookbook'

    assert_redirected_to '/projects/ecookbook/settings/risks'
    assert_equal 0, @project.risk_categories.count
    assert_equal [@technical.id], Risk.where(:id => [1, 2]).distinct.pluck(:category_id)
  end

  def test_put_update_without_permission_should_be_forbidden
    @role.remove_permission!(:manage_project_risk_categories)

    assert_no_difference 'RiskCategory.count' do
      compatible_request :put, :update, :project_id => 'ecookbook', :enumerations => {
        @technical.id.to_s => {:parent_id => @technical.id.to_s, :active => '0'}
      }
    end
    assert_response :forbidden
  end

  def test_put_update_with_module_disabled_should_be_forbidden
    @project.enabled_modules.where(:name => 'risks').delete_all

    compatible_request :put, :update, :project_id => 'ecookbook', :enumerations => {
      @technical.id.to_s => {:parent_id => @technical.id.to_s, :active => '0'}
    }
    assert_response :forbidden
  end
end

class ProjectsControllerRiskCategoriesTabTest < ActionController::TestCase
  tests ProjectsController

  fixtures :projects,
           :users,
           :email_addresses,
           :roles,
           :members,
           :member_roles,
           :enabled_modules,
           :enumerations,
           :trackers,
           :projects_trackers,
           :issue_statuses,
           :issues,
           :risks

  def setup
    @project = Project.find(1)
    EnabledModule.create!(:project => @project, :name => 'risks')
    @role = Role.find(1)
    @role.add_permission!(:manage_project_risk_categories)

    @technical = RiskCategory.create!(:name => 'Technical', :position => 1)
    @legacy = RiskCategory.create!(:name => 'Legacy', :position => 2, :active => false)
    @project.risk_categories.create!(:name => 'Technical', :parent => @technical, :active => false)

    @request.session[:user_id] = 2
  end

  def test_settings_should_list_risk_categories_with_active_checkbox
    compatible_request :get, :settings, :id => 'ecookbook', :tab => 'risks'

    assert_response :success
    assert_select 'a#tab-risks'
    assert_select 'form#project-risk-categories-form[action=?]', '/projects/ecookbook/risk_categories' do
      assert_select 'td.name', :text => 'Technical'
      assert_select 'td.name', :text => 'Legacy'
      assert_select 'input[type=hidden][name=?][value=?]', "enumerations[#{@legacy.id}][parent_id]", @legacy.id.to_s
      assert_select 'input[type=checkbox][name=?]:not([checked])', "enumerations[#{@legacy.id}][active]"
      assert_select 'input.enumerations_active', 2
    end
    assert_select 'a.icon-settings[href=?]', '/enumerations', 0
  end

  def test_settings_without_permission_should_not_show_tab
    @role.remove_permission!(:manage_project_risk_categories)

    compatible_request :get, :settings, :id => 'ecookbook'

    assert_response :success
    assert_select 'a#tab-risks', 0
  end

  def test_settings_with_module_disabled_should_not_show_tab
    @project.enabled_modules.where(:name => 'risks').delete_all

    compatible_request :get, :settings, :id => 'ecookbook'

    assert_response :success
    assert_select 'a#tab-risks', 0
  end

  def test_settings_as_admin_should_link_to_administration
    @request.session[:user_id] = 1

    compatible_request :get, :settings, :id => 'ecookbook', :tab => 'risks'

    assert_response :success
    assert_select 'a.icon-settings[href=?]', '/enumerations'
  end
end
