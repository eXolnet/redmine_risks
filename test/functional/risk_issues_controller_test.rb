require File.expand_path('../../test_helper', __FILE__)

class RiskIssuesControllerTest < ActionController::TestCase
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

  def test_post_create
    compatible_xhr_request :post, :create, :risk_id => 1, :issue_id => 2

    assert_response :success

    risk = Risk.find(1)

    assert_equal 2, risk.issues.count
    assert_equal [1, 2], risk.issues.map(&:id).sort
  end

  def test_delete_destroy
    compatible_xhr_request :delete, :destroy, :risk_id => 1, :issue_id => 1

    assert_response :success

    risk = Risk.find(1)

    assert_equal 0, risk.issues.count
  end

  def test_post_create_should_strip_hash_prefix_and_journalize
    assert_difference 'Journal.count' do
      compatible_xhr_request :post, :create, :risk_id => 1, :issue_id => '#2'
    end

    assert_response :success
    assert_include '#relations', @response.body
    assert_equal [1, 2], Risk.find(1).issues.map(&:id).sort

    detail = Journal.order(:id).last.details.first
    assert_equal ['relation', 'relates', '2'], [detail.property, detail.prop_key, detail.value]
  end

  def test_post_create_with_unknown_issue_should_alert
    assert_no_difference 'Journal.count' do
      compatible_xhr_request :post, :create, :risk_id => 1, :issue_id => '999'
    end

    assert_response :success
    assert_include 'alert(', @response.body
    assert_equal [1], Risk.find(1).issues.map(&:id)
  end

  def test_post_create_with_non_visible_issue_should_alert
    Role.find(2).add_permission!(:view_risks, :manage_risk_relations)
    @request.session[:user_id] = 3 # dlopper, not a member of project 2

    compatible_xhr_request :post, :create, :risk_id => 1, :issue_id => '4' # issue of private project 2

    assert_response :success
    assert_include 'alert(', @response.body
    assert_equal [1], Risk.find(1).issues.map(&:id)
  end

  def test_post_create_without_manage_permission_should_be_denied
    Role.find(2).add_permission!(:view_risks)
    @request.session[:user_id] = 3

    compatible_xhr_request :post, :create, :risk_id => 1, :issue_id => '2'

    assert_response 403
    assert_equal [1], Risk.find(1).issues.map(&:id)
  end

  def test_post_create_with_unknown_risk_should_respond_404
    compatible_xhr_request :post, :create, :risk_id => 999, :issue_id => '2'

    assert_response 404
  end

  def test_delete_destroy_without_manage_permission_should_be_denied
    Role.find(2).add_permission!(:view_risks)
    @request.session[:user_id] = 3

    compatible_xhr_request :delete, :destroy, :risk_id => 1, :issue_id => 1

    assert_response 403
    assert_equal [1], Risk.find(1).issues.map(&:id)
  end

  def test_delete_destroy_should_remove_relation_row
    compatible_xhr_request :delete, :destroy, :risk_id => 1, :issue_id => 1

    assert_response :success
    assert_include "$('#relation-1').remove();", @response.body
  end

  def test_delete_destroy_with_unlinked_issue_should_not_fail
    assert_no_difference 'Journal.count' do
      compatible_xhr_request :delete, :destroy, :risk_id => 1, :issue_id => 2
    end

    assert_response :success
    assert_equal [1], Risk.find(1).issues.map(&:id)
  end
end
