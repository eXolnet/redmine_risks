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
    assert_select 'table.risks tr#risk-1'
    assert_select 'table.risks tr#risk-2', 0 # closed risks are filtered out by default
  end

  def test_get_new
    compatible_request :get, :new, :project_id => 'ecookbook'

    assert_response :success
    assert_select 'form#risk-form[action=?]', '/projects/ecookbook/risks'
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
    assert_select 'div.subject h3', :text => 'Sit sodales posuere'
  end

  def test_get_edit
    compatible_request :get, :edit, :id => 1

    assert_response :success
    assert_select 'input[name=?][value=?]', 'risk[subject]', 'Sit sodales posuere'
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

  def test_delete_destroy_risks_of_several_projects
    EnabledModule.create!(:project_id => 3, :name => 'risks')
    risk = Risk.create!(:project_id => 3, :subject => 'Subproject risk', :author_id => 1)

    compatible_request :delete, :destroy, :ids => [1, risk.id]

    assert_redirected_to '/'
    assert_nil Risk.find_by_id(1)
    assert_nil Risk.find_by_id(risk.id)
  end

  def test_post_bulk_update_risks_of_several_projects
    EnabledModule.create!(:project_id => 3, :name => 'risks')
    risk = Risk.create!(:project_id => 3, :subject => 'Subproject risk', :author_id => 1)

    compatible_request :post, :bulk_update, :ids => [1, risk.id], :risk => {:strategy => 'accept'}

    assert_redirected_to '/'
    assert_equal ['accept'], Risk.where(:id => [1, risk.id]).distinct.pluck(:strategy)
  end

  def test_get_copy_should_prefill_form
    category = RiskCategory.create!(:name => 'Technical')
    Risk.find(1).update_column(:category_id, category.id)

    compatible_request :get, :new, :project_id => 'ecookbook', :copy_from => 1

    assert_response :success
    assert_select 'form#risk-form[action=?]', '/projects/ecookbook/risks' do
      assert_select 'input[type=hidden][name=?][value=?]', 'copy_from', '1'
      assert_select 'select[name=?]', 'risk[project_id]' do
        assert_select 'option[selected=selected][value=?]', '1'
      end
      assert_select 'input[name=?][value=?]', 'risk[subject]', 'Sit sodales posuere'
      assert_select 'textarea[name=?]', 'risk[description]', :text => /Amet tellus quis/
      assert_select 'textarea[name=?]', 'risk[treatments]', :text => /Fringilla nam/
      assert_select 'textarea[name=?]', 'risk[lessons]'
      assert_select 'select[name=?] option[selected=selected][value=?]', 'risk[category_id]', category.id.to_s
      assert_select 'select[name=?] option[selected=selected][value=?]', 'risk[probability]', '25'
      assert_select 'select[name=?] option[selected=selected][value=?]', 'risk[impact]', '50'
      assert_select 'select[name=?] option[selected=selected][value=?]', 'risk[strategy]', 'mitigate'
      assert_select 'select[name=?] option[selected=selected][value=?]', 'risk[assigned_to_id]', '1'
      assert_select 'input[type=checkbox][name=?][checked=checked]', 'copy_issues'
      assert_select 'select[name=?]', 'risk[status]', 0
    end
  end

  def test_get_copy_of_risk_without_issues_should_not_display_copy_issues_option
    Risk.find(1).issues.clear

    compatible_request :get, :new, :project_id => 'ecookbook', :copy_from => 1

    assert_response :success
    assert_select 'input[name=?]', 'copy_issues', 0
  end

  def test_get_copy_with_unknown_risk_should_respond_404
    compatible_request :get, :new, :project_id => 'ecookbook', :copy_from => 999

    assert_response 404
  end

  def test_post_create_copy_should_create_open_risk_with_issues
    assert_difference 'Risk.count' do
      compatible_request :post, :create, :project_id => 'ecookbook', :copy_from => 2, :copy_issues => '1',
        :risk => {:project_id => '1', :subject => 'Copy', :description => 'Description', :strategy => 'transfer'}
    end

    risk = Risk.order('id DESC').first
    assert_redirected_to "/risks/#{risk.id}"
    assert_equal 'Copy', risk.subject
    assert_equal 'transfer', risk.strategy
    assert_equal 'open', risk.status
    assert_nil risk.closed_on
    assert_equal User.find(1), risk.author
    assert_equal Risk.find(2).issue_ids.sort, risk.issue_ids.sort
  end

  def test_post_create_copy_should_copy_related_issues
    compatible_request :post, :create, :project_id => 'ecookbook', :copy_from => 1, :copy_issues => '1',
      :risk => {:project_id => '1', :subject => 'Copy'}

    assert_equal [1], Risk.order('id DESC').first.issue_ids
  end

  def test_post_create_copy_without_copy_issues_should_not_copy_related_issues
    compatible_request :post, :create, :project_id => 'ecookbook', :copy_from => 1,
      :risk => {:project_id => '1', :subject => 'Copy'}

    risk = Risk.order('id DESC').first
    assert_equal 'Copy', risk.subject
    assert_equal [], risk.issue_ids
    assert_equal [1], Risk.find(1).issue_ids
  end

  def test_post_create_copy_should_clear_attributes_emptied_in_form
    compatible_request :post, :create, :project_id => 'ecookbook', :copy_from => 1,
      :risk => {:project_id => '1', :subject => 'Copy', :assigned_to_id => '', :strategy => '', :lessons => ''}

    risk = Risk.order('id DESC').first
    assert_nil risk.assigned_to_id
    assert_nil risk.strategy
    assert_equal 50, risk.impact
  end

  def test_post_create_copy_to_another_project
    EnabledModule.create!(:project => Project.find(2), :name => 'risks')

    assert_difference 'Risk.count' do
      compatible_request :post, :create, :project_id => 'ecookbook', :copy_from => 1, :copy_issues => '1',
        :risk => {:project_id => '2', :subject => 'Copy'}
    end

    risk = Risk.order('id DESC').first
    assert_equal 2, risk.project_id
    assert_equal 1, Risk.find(1).project_id
  end
end
