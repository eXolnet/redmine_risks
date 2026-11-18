require File.expand_path('../../test_helper', __FILE__)

class EnumerationsControllerTest < ActionController::TestCase
  fixtures :projects, :enumerations, :issues, :users, :risks

  def setup
    @controller = EnumerationsController.new

    # Configure the logged user
    @request.session[:user_id] = 1
  end

  def test_index
    get :index
    assert_response :success
    assert_match 'Risk categories', @response.body
  end

  def test_new
    get(:new, :params => {:type => 'RiskCategory'})
    assert_response :success

    assert_select 'input[name=?][value=?]', 'enumeration[type]', 'RiskCategory'
    assert_select 'input[name=?]', 'enumeration[name]'
  end

  def test_create
    assert_difference 'RiskCategory.count' do
      post(
        :create,
        :params => {
          :enumeration => {
            :type => 'RiskCategory',
            :name => 'Low'
          }
        }
      )
    end
    assert_redirected_to '/enumerations'
    e = RiskCategory.find_by_name('Low')
    assert_not_nil e
  end

  def test_index_should_not_list_project_overrides
    technical = RiskCategory.create!(:name => 'Technical')
    Project.find(1).risk_categories.create!(:name => 'Technical', :parent => technical, :active => false)

    get :index
    assert_response :success
    assert_select 'td.name', :text => 'Technical', :count => 1
  end

  def test_destroy_system_category_with_reassign_should_handle_overrides
    technical = RiskCategory.create!(:name => 'Technical')
    financial = RiskCategory.create!(:name => 'Financial')
    override = Project.find(1).risk_categories.create!(:name => 'Technical', :parent => technical, :active => false)
    Risk.where(:id => 1).update_all(:category_id => override.id)

    delete :destroy, :params => {:id => technical.id, :reassign_to_id => financial.id}

    assert_redirected_to '/enumerations'
    assert_nil RiskCategory.find_by_id(technical.id)
    assert_nil RiskCategory.find_by_id(override.id)
    assert_equal financial.id, Risk.find(1).category_id
  end
end
