require File.expand_path('../../test_helper', __FILE__)

class RiskContextMenusControllerTest < ActionController::TestCase
  fixtures :projects,
           :users,
           :roles,
           :members,
           :member_roles,
           :enabled_modules,
           :enumerations,
           :issues,
           :risks,
           :risk_issues

  def setup
    # Enable the Risks module on one project
    @project1 = Project.find(1)
    EnabledModule.create(:project => @project1, :name => 'risks')

    # Configure the logged user
    @request.session[:user_id] = 1
  end

  def test_get_risks_single
    compatible_request :get, :index, :ids => [1]

    assert_response :success
    assert_match 'Impact', @response.body
    assert_match 'Probability', @response.body
    assert_match 'Strategy', @response.body
  end

  def test_get_risks_many
    compatible_request :get, :index, :ids => [1, 2]

    assert_response :success
    assert_match 'Impact', @response.body
    assert_match 'Probability', @response.body
    assert_match 'Strategy', @response.body
  end

  def test_get_risks_many_should_link_edit_to_bulk_edit
    compatible_request :get, :index, :ids => [1, 2], :back_url => '/projects/ecookbook/risks'

    assert_response :success
    assert_select 'a.icon-edit:not(.disabled)[href=?]',
                  '/risks/bulk_edit?back_url=%2Fprojects%2Fecookbook%2Frisks&ids%5B%5D=1&ids%5B%5D=2', :text => 'Bulk edit'
  end

  def test_get_risks_many_without_edit_permission_should_disable_edit
    @request.session[:user_id] = 2
    Role.find(1).add_permission!(:view_risks)
    Role.find(1).remove_permission!(:edit_risks)

    compatible_request :get, :index, :ids => [1, 2]

    assert_response :success
    assert_select 'a.icon-edit.disabled'
  end

  def test_get_risks_single_should_list_menu_entries
    category = RiskCategory.create!(:name => 'Technical')

    compatible_request :get, :index, :ids => [1], :back_url => '/projects/ecookbook/risks'

    assert_response :success
    assert_select 'a.icon-del:not(.disabled)[href=?]', '/risks?back_url=%2Fprojects%2Fecookbook%2Frisks&ids%5B%5D=1'
    assert_select 'a[href*=?]', "risk%5Bcategory_id%5D=#{category.id}", :text => 'Technical'
    assert_select 'a[href*=?]', 'risk%5Bstrategy%5D=accept'
    assert_select 'a.disabled', :text => 'Mitigate'
    assert_select 'a[href*=?]', 'risk%5Bassigned_to_id%5D=2', :text => 'John Smith'
  end

  def test_get_risks_single_should_list_edit_status_and_copy_link
    compatible_request :get, :index, :ids => [1], :back_url => '/projects/ecookbook/risks'

    assert_response :success
    assert_select 'a.icon-edit:not(.disabled)[href=?]', '/risks/1/edit', :text => 'Edit'
    assert_select 'a.submenu', :text => 'Status'
    current = Risk.find(1).status
    assert_select 'a.disabled', :text => I18n.t("label_risk_status_#{current}")
    (Risk::RISK_STATUS - [current]).each do |status|
      assert_select 'a:not(.disabled)[href*=?]', "risk%5Bstatus%5D=#{status}"
    end
    assert_select 'a.icon-copy-link[data-clipboard-text=?]', 'http://test.host/risks/1'
  end

  def test_get_risks_many_should_list_bulk_edit_status_and_copy_link
    compatible_request :get, :index, :ids => [1, 2]

    assert_response :success
    assert_select 'a.icon-edit[href^=?]', '/risks/bulk_edit'
    assert_select 'a.submenu', :text => 'Status'
    assert_select 'a.icon-copy-link[data-clipboard-text=?]', 'http://test.host/projects/ecookbook/risks?risk_id=1%2C2&set_filter=1'
  end

  def test_get_risks_with_unknown_ids_should_respond_404
    compatible_request :get, :index, :ids => [999]

    assert_response 404
  end

  def test_get_risks_without_view_permission_should_be_denied
    @request.session[:user_id] = 4 # Not a member of project 1

    compatible_request :get, :index, :ids => [1]

    assert_response 403
    assert_no_match 'Sit sodales posuere', @response.body
  end

  def test_get_risks_as_anonymous_should_require_login
    @request.session[:user_id] = nil

    compatible_request :get, :index, :ids => [1]

    assert_response 302
    assert_match %r{/login}, @response.location
  end

  def test_get_risks_with_edit_but_without_delete_permission
    Role.find(1).add_permission!(:view_risks, :edit_risks)
    @request.session[:user_id] = 2 # jsmith, Manager on project 1

    compatible_request :get, :index, :ids => [1, 2]

    assert_response :success
    assert_select 'a[href*=?]:not(.disabled)', 'risk%5Bstrategy%5D=accept'
    assert_select 'a.icon-del.disabled'
  end

  def test_get_risks_without_edit_permission_should_disable_links
    Role.find(1).add_permission!(:view_risks)
    @request.session[:user_id] = 2

    compatible_request :get, :index, :ids => [1]

    assert_response :success
    assert_select 'a.icon-del.disabled'
    assert_select 'a[href*=?]', 'risk%5Bstrategy%5D', 0
  end

  def test_get_risks_single_should_list_copy_link
    compatible_request :get, :index, :ids => [1]

    assert_response :success
    assert_select 'a.icon-copy:not(.disabled)[href=?]', '/projects/ecookbook/risks/1/copy'
  end

  def test_get_risks_many_should_not_list_copy_link
    compatible_request :get, :index, :ids => [1, 2]

    assert_response :success
    assert_select 'a.icon-copy', 0
  end

  def test_get_risks_single_without_add_permission_should_disable_copy_link
    Role.find(1).add_permission!(:view_risks)
    Role.find(1).remove_permission!(:add_risks)
    @request.session[:user_id] = 2

    compatible_request :get, :index, :ids => [1]

    assert_response :success
    assert_select 'a.icon-copy.disabled'
  end

  def test_get_risks_should_only_list_active_project_categories
    technical = RiskCategory.create!(:name => 'Technical', :position => 1)
    financial = RiskCategory.create!(:name => 'Financial', :position => 2)
    RiskCategory.create!(:name => 'Legacy', :position => 3, :active => false)
    @project1.risk_categories.create!(:name => 'Financial', :parent => financial, :active => false)

    compatible_request :get, :index, :ids => [1, 2]

    assert_response :success
    assert_select 'a[href*=?]', "risk%5Bcategory_id%5D=#{technical.id}", :text => 'Technical'
    assert_select 'a', :text => 'Financial', :count => 0
    assert_select 'a', :text => 'Legacy', :count => 0
  end
end
