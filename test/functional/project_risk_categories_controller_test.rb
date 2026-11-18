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

  def test_put_bulk_update_should_create_project_override
    assert_difference 'RiskCategory.count' do
      compatible_request :put, :bulk_update, :project_id => 'ecookbook', :enumerations => {
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

  def test_put_bulk_update_should_update_existing_override
    override = @project.risk_categories.create!(:name => 'Technical', :parent => @technical, :active => false)

    compatible_request :put, :bulk_update, :project_id => 'ecookbook', :enumerations => {
      override.id.to_s => {:active => '1'}
    }

    assert_redirected_to '/projects/ecookbook/settings/risks'
    assert override.reload.active?
  end

  def test_delete_destroy_should_reset_overrides_and_restore_risks
    compatible_request :put, :bulk_update, :project_id => 'ecookbook', :enumerations => {
      @technical.id.to_s => {:parent_id => @technical.id.to_s, :active => '0'}
    }
    assert_equal 1, @project.risk_categories.count

    compatible_request :delete, :reset, :project_id => 'ecookbook'

    assert_redirected_to '/projects/ecookbook/settings/risks'
    assert_equal 0, @project.risk_categories.count
    assert_equal [@technical.id], Risk.where(:id => [1, 2]).distinct.pluck(:category_id)
  end

  def test_put_bulk_update_without_permission_should_be_forbidden
    @role.remove_permission!(:manage_project_risk_categories)

    assert_no_difference 'RiskCategory.count' do
      compatible_request :put, :bulk_update, :project_id => 'ecookbook', :enumerations => {
        @technical.id.to_s => {:parent_id => @technical.id.to_s, :active => '0'}
      }
    end
    assert_response :forbidden
  end

  def test_put_bulk_update_with_module_disabled_should_be_forbidden
    @project.enabled_modules.where(:name => 'risks').delete_all

    compatible_request :put, :bulk_update, :project_id => 'ecookbook', :enumerations => {
      @technical.id.to_s => {:parent_id => @technical.id.to_s, :active => '0'}
    }
    assert_response :forbidden
  end

  # Categories specific to the project

  def test_post_create_should_add_project_specific_category
    assert_difference '@project.risk_categories.count' do
      compatible_request :post, :create, :project_id => 'ecookbook', :risk_category => {:name => 'Regulatory'}
    end

    assert_redirected_to '/projects/ecookbook/settings/risks'
    category = @project.risk_categories.last
    assert_equal 'Regulatory', category.name
    assert category.active?
    assert category.project_specific?
    assert_include category, @project.risk_categories_available.to_a
  end

  def test_post_create_without_permission_should_be_forbidden
    @role.remove_permission!(:manage_project_risk_categories)

    assert_no_difference 'RiskCategory.count' do
      compatible_request :post, :create, :project_id => 'ecookbook', :risk_category => {:name => 'Regulatory'}
    end
    assert_response :forbidden
  end

  def test_delete_reset_should_keep_project_specific_categories
    regulatory = @project.risk_categories.create!(:name => 'Regulatory')
    @project.risk_categories.create!(:name => 'Technical', :parent => @technical, :active => false)

    compatible_request :delete, :reset, :project_id => 'ecookbook'

    assert_equal [regulatory], @project.risk_categories.reload.to_a
  end

  def test_delete_destroy_unused_project_specific_category
    regulatory = @project.risk_categories.create!(:name => 'Regulatory')

    assert_difference 'RiskCategory.count', -1 do
      compatible_request :delete, :destroy, :project_id => 'ecookbook', :id => regulatory.id
    end
    assert_redirected_to '/projects/ecookbook/settings/risks'
  end

  def test_delete_destroy_used_category_should_ask_for_reassignment
    regulatory = @project.risk_categories.create!(:name => 'Regulatory')
    Risk.where(:id => 1).update_all(:category_id => regulatory.id)

    assert_no_difference 'RiskCategory.count' do
      compatible_request :delete, :destroy, :project_id => 'ecookbook', :id => regulatory.id
    end
    assert_response :success
    assert_select 'form#risk-category-destroy-form[action=?]', "/projects/ecookbook/risk_categories/#{regulatory.id}" do
      assert_select 'select[name=reassign_to_id]' do
        assert_select 'option[value=""]'
        assert_select 'option[value=?]', @technical.id.to_s
        assert_select 'option[value=?]', regulatory.id.to_s, 0
      end
    end
  end

  def test_delete_destroy_used_category_with_reassign
    regulatory = @project.risk_categories.create!(:name => 'Regulatory')
    Risk.where(:id => 1).update_all(:category_id => regulatory.id)

    compatible_request :delete, :destroy, :project_id => 'ecookbook', :id => regulatory.id,
                       :reassign_to_id => @financial.id

    assert_redirected_to '/projects/ecookbook/settings/risks'
    assert_nil RiskCategory.find_by_id(regulatory.id)
    assert_equal @financial.id, Risk.find(1).category_id
  end

  def test_delete_destroy_used_category_without_reassign_should_clear_category
    regulatory = @project.risk_categories.create!(:name => 'Regulatory')
    Risk.where(:id => 1).update_all(:category_id => regulatory.id)

    compatible_request :delete, :destroy, :project_id => 'ecookbook', :id => regulatory.id, :reassign_to_id => ''

    assert_redirected_to '/projects/ecookbook/settings/risks'
    assert_nil RiskCategory.find_by_id(regulatory.id)
    assert_nil Risk.find(1).category_id
  end

  def test_delete_destroy_with_reassign_to_category_of_another_project_should_respond_404
    regulatory = @project.risk_categories.create!(:name => 'Regulatory')
    Risk.where(:id => 1).update_all(:category_id => regulatory.id)
    marketing = Project.find(2).risk_categories.create!(:name => 'Marketing')

    compatible_request :delete, :destroy, :project_id => 'ecookbook', :id => regulatory.id,
                       :reassign_to_id => marketing.id

    assert_response :not_found
    assert_not_nil RiskCategory.find_by_id(regulatory.id)
  end

  def test_delete_destroy_override_or_system_category_should_respond_404
    override = @project.risk_categories.create!(:name => 'Technical', :parent => @technical, :active => false)

    compatible_request :delete, :destroy, :project_id => 'ecookbook', :id => override.id
    assert_response :not_found

    compatible_request :delete, :destroy, :project_id => 'ecookbook', :id => @financial.id
    assert_response :not_found
    assert_not_nil RiskCategory.find_by_id(override.id)
  end

  def test_delete_destroy_category_of_another_project_should_respond_404
    marketing = Project.find(2).risk_categories.create!(:name => 'Marketing')

    compatible_request :delete, :destroy, :project_id => 'ecookbook', :id => marketing.id

    assert_response :not_found
    assert_not_nil RiskCategory.find_by_id(marketing.id)
  end

  def test_get_new
    compatible_request :get, :new, :project_id => 'ecookbook'

    assert_response :success
    assert_select 'form#risk-category-form[action=?][method=post]', '/projects/ecookbook/risk_categories' do
      assert_select 'input[name=?]', 'risk_category[name]'
    end
  end

  def test_post_create_with_system_category_name_should_render_errors
    assert_no_difference 'RiskCategory.count' do
      compatible_request :post, :create, :project_id => 'ecookbook', :risk_category => {:name => 'Technical'}
    end

    assert_response :success
    assert_select '#errorExplanation'
    assert_select 'input[name=?][value=?]', 'risk_category[name]', 'Technical'
  end

  def test_get_edit
    regulatory = @project.risk_categories.create!(:name => 'Regulatory')

    compatible_request :get, :edit, :project_id => 'ecookbook', :id => regulatory.id

    assert_response :success
    assert_select 'form#risk-category-form[action=?]', "/projects/ecookbook/risk_categories/#{regulatory.id}" do
      assert_select 'input[name=?][value=?]', 'risk_category[name]', 'Regulatory'
    end
  end

  def test_get_edit_override_should_respond_404
    override = @project.risk_categories.create!(:name => 'Technical', :parent => @technical, :active => false)

    compatible_request :get, :edit, :project_id => 'ecookbook', :id => override.id
    assert_response :not_found
  end

  def test_put_update_should_rename_project_specific_category
    regulatory = @project.risk_categories.create!(:name => 'Regulatory')

    compatible_request :put, :update, :project_id => 'ecookbook', :id => regulatory.id,
                       :risk_category => {:name => 'Compliance'}

    assert_redirected_to '/projects/ecookbook/settings/risks'
    assert_equal 'Compliance', regulatory.reload.name
    assert regulatory.active?
  end

  def test_put_update_with_invalid_name_should_render_errors
    regulatory = @project.risk_categories.create!(:name => 'Regulatory')

    compatible_request :put, :update, :project_id => 'ecookbook', :id => regulatory.id,
                       :risk_category => {:name => 'Financial'}

    assert_response :success
    assert_select '#errorExplanation'
    assert_equal 'Regulatory', regulatory.reload.name
  end

  def test_put_update_category_of_another_project_should_respond_404
    marketing = Project.find(2).risk_categories.create!(:name => 'Marketing')

    compatible_request :put, :update, :project_id => 'ecookbook', :id => marketing.id,
                       :risk_category => {:name => 'Other'}

    assert_response :not_found
    assert_equal 'Marketing', marketing.reload.name
  end

  def test_put_bulk_update_should_disable_project_specific_category_without_renaming_it
    regulatory = @project.risk_categories.create!(:name => 'Regulatory')

    compatible_request :put, :bulk_update, :project_id => 'ecookbook', :enumerations => {
      regulatory.id.to_s => {:name => 'Other', :active => '0'}
    }

    assert_redirected_to '/projects/ecookbook/settings/risks'
    regulatory.reload
    assert_equal 'Regulatory', regulatory.name
    assert_not regulatory.active?
  end

  def test_get_new_without_permission_should_be_forbidden
    @role.remove_permission!(:manage_project_risk_categories)

    compatible_request :get, :new, :project_id => 'ecookbook'
    assert_response :forbidden
  end

  def test_xhr_put_update_should_move_project_specific_category
    regulatory = @project.risk_categories.create!(:name => 'Regulatory')
    compliance = @project.risk_categories.create!(:name => 'Compliance')

    compatible_xhr_request :put, :update, :project_id => 'ecookbook', :id => compliance.id,
                           :risk_category => {:position => 1}, :format => 'js'

    assert_response :success
    assert_equal 1, compliance.reload.position
    assert_equal 2, regulatory.reload.position
    assert_equal [compliance, regulatory], @project.risk_categories_available.to_a.last(2)
  end

  def test_xhr_put_update_with_invalid_name_should_respond_422
    regulatory = @project.risk_categories.create!(:name => 'Regulatory')

    compatible_xhr_request :put, :update, :project_id => 'ecookbook', :id => regulatory.id,
                           :risk_category => {:name => ''}, :format => 'js'

    assert_response 422
  end

  def test_post_create_should_ignore_position
    @project.risk_categories.create!(:name => 'Regulatory')

    compatible_request :post, :create, :project_id => 'ecookbook', :risk_category => {:name => 'Compliance', :position => 1}

    assert_equal %w(Regulatory Compliance), @project.risk_categories.where(:parent_id => nil).sorted.map(&:name)
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

  def test_settings_should_display_project_specific_categories
    regulatory = @project.risk_categories.create!(:name => 'Regulatory')

    compatible_request :get, :settings, :id => 'ecookbook', :tab => 'risks'

    assert_response :success
    assert_select 'a.icon-add[href=?]', '/projects/ecookbook/risk_categories/new'
    assert_select "tr#risk-category-#{regulatory.id}.project-specific" do
      assert_select 'td.name', :text => 'Regulatory'
      assert_select 'input[type=text]', 0
      assert_select 'input[type=checkbox][name=?][checked]', "enumerations[#{regulatory.id}][active]"
      assert_select 'a.icon-edit[href=?]', "/projects/ecookbook/risk_categories/#{regulatory.id}/edit"
      assert_select 'a.icon-del[href=?][data-method=delete]', "/projects/ecookbook/risk_categories/#{regulatory.id}"
    end
    assert_select "tr#risk-category-#{@legacy.id}.system" do
      assert_select 'a.icon-edit', 0
      assert_select 'a.icon-del', 0
    end
  end

  def test_settings_should_allow_reordering_project_specific_categories_only
    regulatory = @project.risk_categories.create!(:name => 'Regulatory')
    compliance = @project.risk_categories.create!(:name => 'Compliance')

    compatible_request :get, :settings, :id => 'ecookbook', :tab => 'risks'

    assert_response :success
    assert_select 'table.risk-categories tbody.system-categories tr', 2 do
      assert_select '.sort-handle', 0
    end
    assert_select 'table.risk-categories tbody.project-specific-categories tr.project-specific', 2
    assert_select 'tbody.project-specific-categories tr:first-child td.name', :text => 'Regulatory'
    assert_select "tr#risk-category-#{compliance.id} .sort-handle[data-reorder-url=?][data-reorder-param=?]",
                  "/projects/ecookbook/risk_categories/#{compliance.id}", 'risk_category'
    assert_match 'positionedItems', response.body
  end
end
