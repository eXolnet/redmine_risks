require File.expand_path('../../test_helper', __FILE__)

class RisksControllerTest < ActionController::TestCase
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

  def test_get_index_with_project
    compatible_request :get, :index, :project_id => 'ecookbook'

    assert_response :success
  end

  def test_get_new
    compatible_request :get, :new, :project_id => 'ecookbook'

    assert_response :success
  end

  def test_post_create
    assert_difference 'Risk.count' do
      compatible_request :post, :create, :project_id => 'ecookbook',
        :risk => {
          :subject => 'Subject',
          :description => 'Description',
          :assigned_to_id => 2,
          :category_id => 1,
          :probability => 25,
          :impact => 75,
        }

        assert_response 302
    end

    risk = Risk.order('id DESC').first
    assert_equal 'Subject', risk.subject
    assert_equal 'Description', risk.description
    assert_equal 2, risk.assigned_to_id
    assert_equal 1, risk.category_id
    assert_equal 25, risk.probability
    assert_equal 75, risk.impact
  end

  def test_get_show
    compatible_request :get, :show, :id => 1

    assert_response :success
  end

  def test_get_edit
    compatible_request :get, :edit, :id => 1

    assert_response :success
  end

  def test_put_update
    compatible_request :put, :update, :id => 1,
      :risk => {
        :subject => 'Subject',
        :description => 'Description',
        :assigned_to_id => 2,
        :category_id => 1,
        :probability => 25,
        :impact => 75,
      }

    assert_response 302

    risk = Risk.find(1)
    assert_equal 'Subject', risk.subject
    assert_equal 'Description', risk.description
    assert_equal 2, risk.assigned_to_id
    assert_equal 1, risk.category_id
    assert_equal 25, risk.probability
    assert_equal 75, risk.impact
  end

  def test_put_update_empty
    compatible_request :put, :update, :id => 1,
      :risk => {
        :description => '',
        :assigned_to_id => '',
        :category_id => '',
        :probability => '',
        :impact => '',
        :strategy => '',
        :treatments => '',
        :lessons => '',
      }

    assert_response 302

    risk = Risk.find(1)
    assert_equal 'Sit sodales posuere', risk.subject
    assert_nil risk.description
    assert_nil risk.assigned_to_id
    assert_nil risk.category_id
    assert_nil risk.probability
    assert_nil risk.impact
    assert_nil risk.strategy
    assert_nil risk.treatments
    assert_nil risk.lessons
  end

  def test_put_update_clear_optional_fields
    compatible_request :put, :update, :id => 1

    assert_response 302

    risk = Risk.find(1)
    assert_equal 'Sit sodales posuere', risk.subject
    assert_equal 'Amet tellus quis phasellus dis ultrices nulla', risk.description
    assert_equal 1, risk.assigned_to_id
    assert_equal 1, risk.category_id
    assert_equal 25, risk.probability
    assert_equal 50, risk.impact
  end

  def test_delete_destroy
    compatible_request :delete, :destroy, :id => 1

    assert_response 302
    assert ! Risk.find_by_id(1)
  end

  def test_delete_destroy_many
    compatible_request :delete, :destroy, :ids => [1, 2]

    assert_response 302
    assert ! Risk.find_by_id(1)
    assert ! Risk.find_by_id(2)
  end

  def test_get_preview_for_new_risk
    compatible_request :get, :preview, :project_id => 'ecookbook',
      :risk => {
        :description => '*Rhoncus turpis* magnis blandit'
      }

    assert_response :success
    assert_match /<(em|strong)>Rhoncus turpis<\/\1> magnis blandit/, @response.body
  end

  def test_get_preview_for_existing_risk
    compatible_request :get, :preview, :id => 1,
      :risk => {
        :description => '*Rhoncus turpis* magnis blandit'
      }

    assert_response :success
    assert_match /<(em|strong)>Rhoncus turpis<\/\1> magnis blandit/, @response.body
  end

  def test_post_quoted
    compatible_xhr_request :post, :quoted, :id => 1

    assert_response :success
    assert_match '> Amet tellus quis phasellus dis ultrices nulla', @response.body
  end

  def test_post_bulk_update
    compatible_request :post, :bulk_update, :ids => [1, 2],
      :risk => {
        :probability => 75,
        :impact => 100,
        :strategy => 'eliminate',
      }

    assert_response 302

    risk1 = Risk.find(1)
    assert_equal 75, risk1.probability
    assert_equal 100, risk1.impact
    assert_equal 'eliminate', risk1.strategy

    risk2 = Risk.find(2)
    assert_equal 75, risk2.probability
    assert_equal 100, risk2.impact
    assert_equal 'eliminate', risk2.strategy
  end
end
