require File.expand_path('../../test_helper', __FILE__)

class IssueRisksControllerTest < ActionController::TestCase
  fixtures :projects,
           :users,
           :email_addresses,
           :roles,
           :members,
           :member_roles,
           :enabled_modules,
           :enumerations,
           :trackers,
           :issue_statuses,
           :issues,
           :risks,
           :risk_issues

  def setup
    EnabledModule.create(:project => Project.find(1), :name => 'risks')
    @request.session[:user_id] = 1
  end

  def test_post_create_should_link_risk_and_journalize
    assert_difference 'Journal.count' do
      compatible_xhr_request :post, :create, :issue_id => 1, :risk_id => '#2'
    end

    assert_response :success
    assert_include '#issue-risks', @response.body
    assert_include 'issue-risk-2', @response.body
    assert_equal [1, 2], Issue.find(1).risks.map(&:id).sort

    journal = Journal.order(:id).last
    assert_equal 'Risk', journal.journalized_type
    assert_equal 2, journal.journalized_id

    detail = journal.details.first
    assert_equal ['relation', 'relates', '1'], [detail.property, detail.prop_key, detail.value]
  end

  def test_post_create_with_already_linked_risk_should_alert
    assert_no_difference 'Journal.count' do
      compatible_xhr_request :post, :create, :issue_id => 1, :risk_id => '1'
    end

    assert_response :success
    assert_include 'alert(', @response.body
    assert_equal [1], Issue.find(1).risks.map(&:id)
  end

  def test_post_create_with_unknown_risk_should_alert
    assert_no_difference 'Journal.count' do
      compatible_xhr_request :post, :create, :issue_id => 1, :risk_id => '999'
    end

    assert_response :success
    assert_include 'alert(', @response.body
  end

  def test_post_create_without_manage_permission_should_alert
    Role.find(1).add_permission!(:view_risks)
    Role.find(1).remove_permission!(:manage_risk_relations)
    @request.session[:user_id] = 2 # jsmith, manager of project 1

    assert_no_difference 'Journal.count' do
      compatible_xhr_request :post, :create, :issue_id => 2, :risk_id => '1'
    end

    assert_response :success
    assert_include 'alert(', @response.body
    assert_equal [1], Risk.find(1).issues.map(&:id)
  end

  def test_post_create_with_non_visible_issue_should_return_404
    @request.session[:user_id] = 3 # dlopper, not a member of private project 2

    compatible_xhr_request :post, :create, :issue_id => 4, :risk_id => '1'

    assert_response :not_found
    assert_equal [1], Risk.find(1).issues.map(&:id)
  end

  def test_delete_destroy_should_unlink_risk_and_journalize
    assert_difference 'Journal.count' do
      compatible_xhr_request :delete, :destroy, :issue_id => 1, :risk_id => 1
    end

    assert_response :success
    assert_include '#issue-risks', @response.body
    assert_equal [], Issue.find(1).risks.to_a

    detail = Journal.order(:id).last.details.first
    assert_equal ['relation', 'relates', '1'], [detail.property, detail.prop_key, detail.old_value]
  end

  def test_delete_destroy_with_unlinked_risk_should_alert
    assert_no_difference 'Journal.count' do
      compatible_xhr_request :delete, :destroy, :issue_id => 1, :risk_id => 2
    end

    assert_response :success
    assert_include 'alert(', @response.body
  end
end
