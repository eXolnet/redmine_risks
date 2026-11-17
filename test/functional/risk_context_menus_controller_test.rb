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
end
