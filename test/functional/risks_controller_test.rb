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
    assert_select 'label[for=risk_assigned_to_id]', :text => 'Assignee'
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

  def test_get_bulk_edit
    compatible_request :get, :bulk_edit, :ids => [1, 2]

    assert_response :success
    assert_select 'ul#bulk-selection li', 2
    assert_select 'ul#bulk-selection li', :text => 'Risk #1: Sit sodales posuere' do
      assert_select 'a[href=?]', '/risks/1', :text => 'Risk #1'
    end
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

  def test_get_edit_should_not_separate_submit_and_cancel_with_a_pipe
    compatible_request :get, :edit, :id => 1

    assert_response :success
    assert_select 'form#risk-form a[href=?]', '/risks/1', :text => 'Cancel'
    assert_no_match /\|\s*<a[^>]*>Cancel</, response.body
  end

  def test_get_edit_and_bulk_edit_should_label_assignee_consistently
    compatible_request :get, :edit, :id => 1
    assert_select 'label[for=risk_assigned_to_id]', :text => 'Assignee'

    compatible_request :get, :bulk_edit, :ids => [1, 2]
    assert_select 'label[for=risk_assigned_to_id]', :text => 'Assignee'
  end

  def test_get_bulk_edit_should_display_risk_custom_fields
    string = RiskCustomField.create!(:name => 'Owner team', :field_format => 'string')
    list = RiskCustomField.create!(:name => 'Source', :field_format => 'list', :possible_values => ['Internal', 'Vendor'])

    compatible_request :get, :bulk_edit, :ids => [1, 2]

    assert_response :success
    assert_select 'form#bulk_edit_form' do
      assert_select 'input[type=text][name=?]', "risk[custom_field_values][#{string.id}]"
      assert_select 'select[name=?]', "risk[custom_field_values][#{list.id}]" do
        assert_select 'option[value=""]', :text => '(No change)'
        assert_select 'option[value=?]', '__none__'
        assert_select 'option[value=?]', 'Vendor'
      end
    end
  end

  def test_get_bulk_edit_should_display_full_width_custom_fields
    field = RiskCustomField.create!(:name => 'Context', :field_format => 'text', :full_width_layout => '1', :text_formatting => 'full')

    compatible_request :get, :bulk_edit, :ids => [1, 2]

    assert_response :success
    assert_select 'textarea[name=?].wiki-edit', "risk[custom_field_values][#{field.id}]"
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

  def test_post_bulk_update_should_update_custom_fields_and_journalize_them
    field = RiskCustomField.create!(:name => 'Owner team', :field_format => 'string')

    assert_difference 'Journal.where(:journalized_type => "Risk").count', 2 do
      compatible_request :post, :bulk_update, :ids => [1, 2],
        :risk => {:custom_field_values => {field.id.to_s => 'Ops'}}
    end

    assert_redirected_to '/projects/ecookbook/risks'
    [1, 2].each do |id|
      assert_equal 'Ops', Risk.find(id).custom_field_value(field)
      detail = Journal.where(:journalized_type => 'Risk', :journalized_id => id).last.details.first
      assert_equal 'cf', detail.property
      assert_equal field.id.to_s, detail.prop_key
      assert_equal 'Ops', detail.value
    end
  end

  def test_post_bulk_update_should_leave_custom_fields_with_no_change_untouched
    field = RiskCustomField.create!(:name => 'Owner team', :field_format => 'string')
    Risk.find(1).tap {|r| r.custom_field_values = {field.id => 'Ops'}; r.save!}

    compatible_request :post, :bulk_update, :ids => [1, 2],
      :risk => {:strategy => 'accept', :custom_field_values => {field.id.to_s => ''}}

    assert_equal 'Ops', Risk.find(1).custom_field_value(field)
    assert_equal 'accept', Risk.find(1).strategy
  end

  def test_post_bulk_update_should_clear_custom_field_with_none
    field = RiskCustomField.create!(:name => 'Source', :field_format => 'list', :possible_values => ['Internal', 'Vendor'])
    [1, 2].each {|id| Risk.find(id).tap {|r| r.custom_field_values = {field.id => 'Vendor'}; r.save!}}

    compatible_request :post, :bulk_update, :ids => [1, 2],
      :risk => {:custom_field_values => {field.id.to_s => '__none__'}}

    assert_equal ['', ''], [1, 2].map {|id| Risk.find(id).custom_field_value(field).to_s}
  end

  def test_post_bulk_update_with_invalid_custom_field_value_should_report_errors
    field = RiskCustomField.create!(:name => 'Score', :field_format => 'int')

    compatible_request :post, :bulk_update, :ids => [1, 2],
      :risk => {:custom_field_values => {field.id.to_s => 'abc'}}

    assert_response :success
    assert_select '#errorExplanation li', :text => /Score is not a number/
    assert_select "input[name=?][value=?]", "risk[custom_field_values][#{field.id}]", 'abc'
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

  def test_get_new_should_only_list_active_project_categories
    technical = RiskCategory.create!(:name => 'Technical', :position => 1)
    financial = RiskCategory.create!(:name => 'Financial', :position => 2)
    RiskCategory.create!(:name => 'Legacy', :position => 3, :active => false)
    @project1.risk_categories.create!(:name => 'Financial', :parent => financial, :active => false)

    compatible_request :get, :new, :project_id => 'ecookbook'

    assert_response :success
    assert_select 'select#risk_category_id' do
      assert_select 'option', 2 # blank + Technical
      assert_select 'option[value=?]', technical.id.to_s, :text => 'Technical'
    end
  end

  def test_get_edit_should_keep_current_category_disabled_in_project
    technical = RiskCategory.create!(:name => 'Technical')
    override = @project1.risk_categories.create!(:name => 'Technical', :parent => technical, :active => false)
    Risk.where(:id => 1).update_all(:category_id => override.id)

    compatible_request :get, :edit, :id => 1

    assert_response :success
    assert_select 'select#risk_category_id option[selected][value=?]', override.id.to_s, :text => 'Technical'
  end

  def test_post_create_with_category_disabled_in_project_should_fail
    technical = RiskCategory.create!(:name => 'Technical')
    @project1.risk_categories.create!(:name => 'Technical', :parent => technical, :active => false)

    assert_no_difference 'Risk.count' do
      compatible_request :post, :create, :project_id => 'ecookbook',
                         :risk => {:subject => 'New risk', :category_id => technical.id}
    end
    assert_response :success
    assert_select '#errorExplanation'
  end

  def test_post_create_copy_to_project_should_map_category_override
    technical = RiskCategory.create!(:name => 'Technical')
    override = @project1.risk_categories.create!(:name => 'Technical', :parent => technical, :active => false)
    Risk.where(:id => 1).update_all(:category_id => override.id)
    EnabledModule.create!(:project_id => 2, :name => 'risks')

    assert_difference 'Risk.count' do
      compatible_request :post, :create, :project_id => 'ecookbook', :copy_from => 1,
        :risk => {:project_id => '2', :subject => 'Copy', :category_id => override.id.to_s}
    end

    risk = Risk.order('id DESC').first
    assert_equal 2, risk.project_id
    assert_equal technical, risk.category
  end

  def test_get_copy_with_category_disabled_in_project_should_not_preselect_it
    technical = RiskCategory.create!(:name => 'Technical')
    override = @project1.risk_categories.create!(:name => 'Technical', :parent => technical, :active => false)
    Risk.where(:id => 1).update_all(:category_id => override.id)

    compatible_request :get, :new, :project_id => 'ecookbook', :copy_from => 1

    assert_response :success
    assert_select 'select#risk_category_id option[value=?]', override.id.to_s, 0
  end

  def test_get_bulk_edit_should_only_list_categories_active_in_all_projects
    technical = RiskCategory.create!(:name => 'Technical', :position => 1)
    financial = RiskCategory.create!(:name => 'Financial', :position => 2)
    RiskCategory.create!(:name => 'Legacy', :position => 3, :active => false)
    @project1.risk_categories.create!(:name => 'Financial', :parent => financial, :active => false)

    compatible_request :get, :bulk_edit, :ids => [1, 2]

    assert_response :success
    assert_select 'select[name=?]', 'risk[category_id]' do
      assert_select 'option[value=?]', technical.id.to_s, :text => 'Technical'
      assert_select 'option', :text => 'Financial', :count => 0
      assert_select 'option', :text => 'Legacy', :count => 0
    end
  end
end
