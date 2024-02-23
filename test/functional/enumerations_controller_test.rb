require File.expand_path('../../test_helper', __FILE__)

class EnumerationsControllerTest < ActionController::TestCase
  fixtures :enumerations, :issues, :users

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
end
