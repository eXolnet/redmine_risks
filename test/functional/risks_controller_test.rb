require File.expand_path('../../test_helper', __FILE__)

class RisksControllerTest < ActionController::TestCase
  fixtures :projects,
           :users,
           :roles,
           :members,
           :member_roles,
           :enabled_modules,
           :enumerations

  def setup
    # Configure the logged user
    @request.session[:user_id] = 1

    # Enable the Risks module on one project
    @project1 = Project.find(1)
    EnabledModule.create(:project => @project1, :name => 'risks')
  end

  def test_get_index_with_project
    get :index, :params => { :project_id => 'ecookbook' }

    assert_response :success
  end
end
