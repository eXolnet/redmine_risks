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
end
