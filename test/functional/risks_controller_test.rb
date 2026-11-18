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


  def test_get_new_should_display_risk_custom_fields
    field = RiskCustomField.create!(:name => 'Owner team', :field_format => 'string', :is_required => true)

    compatible_request :get, :new, :project_id => 'ecookbook'

    assert_response :success
    assert_select 'input[name=?]', "risk[custom_field_values][#{field.id}]"
    assert_select 'label[for=?] span.required', "risk_custom_field_values_#{field.id}"
  end

  def test_post_create_with_risk_custom_field
    field = RiskCustomField.create!(:name => 'Owner team', :field_format => 'string')

    assert_difference 'Risk.count' do
      compatible_request :post, :create, :project_id => 'ecookbook',
        :risk => {:subject => 'Subject', :custom_field_values => {field.id.to_s => 'Ops'}}
    end

    assert_equal 'Ops', Risk.order(:id).last.custom_field_value(field)
  end

  def test_post_create_without_required_risk_custom_field_should_fail
    RiskCustomField.create!(:name => 'Owner team', :field_format => 'string', :is_required => true)

    assert_no_difference 'Risk.count' do
      compatible_request :post, :create, :project_id => 'ecookbook', :risk => {:subject => 'Subject'}
    end

    assert_response :success
    assert_select '#errorExplanation', :text => /Owner team/
  end

  def test_get_edit_should_display_risk_custom_field_value
    field = RiskCustomField.create!(:name => 'Owner team', :field_format => 'string')
    risk = Risk.find(1)
    risk.custom_field_values = {field.id.to_s => 'Ops'}
    risk.save!

    compatible_request :get, :edit, :id => 1

    assert_response :success
    assert_select 'input[name=?][value=?]', "risk[custom_field_values][#{field.id}]", 'Ops'
  end

  def test_put_update_with_risk_custom_field_should_journalize_the_change
    field = RiskCustomField.create!(:name => 'Owner team', :field_format => 'string')

    assert_difference 'Journal.count' do
      compatible_request :put, :update, :id => 1, :risk => {:custom_field_values => {field.id.to_s => 'Ops'}}
    end

    assert_response 302
    assert_equal 'Ops', Risk.find(1).custom_field_value(field)

    compatible_request :get, :show, :id => 1
    assert_select '#history ul.details li', :text => /Owner team.*Ops/
  end

  def test_get_show_should_display_visible_risk_custom_fields
    field = RiskCustomField.create!(:name => 'Owner team', :field_format => 'string')
    long_field = RiskCustomField.create!(:name => 'Context', :field_format => 'text', :full_width_layout => '1')
    risk = Risk.find(1)
    risk.custom_field_values = {field.id.to_s => 'Ops', long_field.id.to_s => 'Long context'}
    risk.save!

    compatible_request :get, :show, :id => 1

    assert_response :success
    assert_select "div.attributes div.cf_#{field.id} div.value", :text => 'Ops'
    assert_select "div.cf_#{long_field.id} div.value", :text => /Long context/
  end

  def test_get_show_should_hide_risk_custom_fields_not_visible_by_the_user
    Role.find(2).add_permission!(:view_risks, :edit_risks)
    field = RiskCustomField.create!(:name => 'Managers only', :field_format => 'string', :visible => false, :role_ids => [1])
    risk = Risk.find(1)
    risk.custom_field_values = {field.id.to_s => 'Secret'}
    risk.save!
    @request.session[:user_id] = 3 # dlopper is Developer

    compatible_request :get, :show, :id => 1

    assert_response :success
    assert_select "div.cf_#{field.id}", 0
    assert_select 'input[name=?]', "risk[custom_field_values][#{field.id}]", 0
  end

  def test_get_index_with_risk_custom_field_column_and_group
    field = RiskCustomField.create!(:name => 'Owner team', :field_format => 'list', :possible_values => ['Dev', 'Ops'])
    risk = Risk.find(1)
    risk.custom_field_values = {field.id.to_s => 'Ops'}
    risk.save!

    compatible_request :get, :index, :project_id => 'ecookbook', :set_filter => 1,
      :c => ['subject', "cf_#{field.id}"], :group_by => "cf_#{field.id}"

    assert_response :success
    assert_select "table.risks th", :text => 'Owner team'
    assert_select "table.risks tr#risk-1 td.cf_#{field.id}", :text => 'Ops'
    assert_select 'tr.group span.name', :text => 'Ops'
  end
end
