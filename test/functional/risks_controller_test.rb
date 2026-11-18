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

  def test_get_bulk_edit
    compatible_request :get, :bulk_edit, :ids => [1, 2]

    assert_response :success
    assert_select 'ul#bulk-selection li', 2
    assert_select 'form#bulk_edit_form[action=?]', '/risks/bulk_update' do
      assert_select 'input[name=?][value=?]', 'ids[]', '1'
      assert_select 'input[name=?][value=?]', 'ids[]', '2'
      %w(status category_id probability impact strategy assigned_to_id).each do |field|
        assert_select "select[name=?]", "risk[#{field}]" do
          assert_select 'option:first-child[value=""]', :text => '(No change)'
        end
      end
      assert_select 'select[name=?] option[value=?]', 'risk[strategy]', 'none'
      assert_select 'select[name=?] option[value=?]', 'risk[status]', 'closed'
      assert_select 'textarea[name=?]', 'notes'
    end
  end

  def test_get_bulk_edit_should_display_bulk_editable_custom_fields
    field = IssueCustomField.create!(:name => 'Risk owner team', :field_format => 'string', :is_for_all => true)
    Risk.any_instance.stubs(:available_custom_fields).returns([field])

    compatible_request :get, :bulk_edit, :ids => [1, 2]

    assert_response :success
    assert_select 'input[name=?]', "risk[custom_field_values][#{field.id}]"
  end

  def test_get_bulk_edit_with_unknown_risk_should_return_404
    compatible_request :get, :bulk_edit, :ids => [999]

    assert_response 404
  end

  def test_post_bulk_update_should_leave_unchanged_fields_untouched
    compatible_request :post, :bulk_update, :ids => [1, 2],
      :risk => {
        :status => '',
        :category_id => '',
        :probability => '',
        :impact => '',
        :strategy => 'accept',
        :assigned_to_id => '',
      }

    assert_redirected_to '/projects/ecookbook/risks'

    risk1 = Risk.find(1)
    assert_equal 'open', risk1.status
    assert_equal 1, risk1.category_id
    assert_equal 25, risk1.probability
    assert_equal 50, risk1.impact
    assert_equal 1, risk1.assigned_to_id
    assert_equal 'accept', risk1.strategy

    risk2 = Risk.find(2)
    assert_equal 'closed', risk2.status
    assert_equal 50, risk2.probability
    assert_equal 75, risk2.impact
    assert_equal 'accept', risk2.strategy
  end

  def test_post_bulk_update_should_change_status_assignee_and_category
    category = RiskCategory.create!(:name => 'Technical')

    compatible_request :post, :bulk_update, :ids => [1, 2],
      :risk => {:status => 'rejected', :assigned_to_id => 'none', :category_id => category.id}

    Risk.where(:id => [1, 2]).each do |risk|
      assert_equal 'rejected', risk.status
      assert_not_nil risk.closed_on
      assert_nil risk.assigned_to_id
      assert_equal category.id, risk.category_id
    end
  end

  def test_post_bulk_update_should_create_one_journal_per_risk
    assert_difference 'Journal.where(:journalized_type => "Risk").count', 2 do
      compatible_request :post, :bulk_update, :ids => [1, 2], :notes => 'Revue des risques', :risk => {:impact => 100}
    end

    [1, 2].each do |id|
      journal = Journal.where(:journalized_type => 'Risk', :journalized_id => id).last
      assert_equal 'Revue des risques', journal.notes
      assert_equal 1, journal.user_id
      assert journal.details.any? {|d| d.prop_key == 'impact' && d.value == '100'}
    end
  end

  def test_post_bulk_update_should_update_custom_fields
    field = IssueCustomField.create!(:name => 'Risk owner team', :field_format => 'string', :is_for_all => true)
    Risk.any_instance.stubs(:available_custom_fields).returns([field])

    compatible_request :post, :bulk_update, :ids => [1, 2],
      :risk => {:custom_field_values => {field.id.to_s => 'Ops'}}

    assert_redirected_to '/projects/ecookbook/risks'
    assert_equal ['Ops', 'Ops'],
      CustomValue.where(:customized_type => 'Risk', :customized_id => [1, 2], :custom_field_id => field.id).pluck(:value)
  end

  def test_post_bulk_update_should_report_unsaved_risks_without_blocking_others
    Risk.find(2).update_column(:subject, '')

    assert_difference 'Journal.where(:journalized_type => "Risk").count', 1 do
      compatible_request :post, :bulk_update, :ids => [1, 2], :notes => 'Bulk', :risk => {:strategy => 'accept'}
    end

    assert_response :success
    assert_select '#errorExplanation', :text => /1 risk\(s\) on 2 selected could not be saved: #2/
    assert_select 'ul#bulk-selection li', 1
    assert_select 'input[name=?][value=?]', 'ids[]', '2'
    assert_select 'select[name=?] option[value=?][selected=selected]', 'risk[strategy]', 'accept'
    assert_equal 'accept', Risk.find(1).strategy
    assert_equal 'transfer', Risk.find(2).strategy
  end
end
