require File.expand_path('../../test_helper', __FILE__)

# Tests RisksController as a regular project member (jsmith, Manager on eCookbook)
class RisksControllerPermissionsTest < ActionController::TestCase
  tests RisksController

  fixtures :projects,
           :users,
           :email_addresses,
           :roles,
           :members,
           :member_roles,
           :enabled_modules,
           :enumerations,
           :trackers,
           :projects_trackers,
           :issue_statuses,
           :issues,
           :journals,
           :journal_details,
           :risks,
           :risk_issues

  RISK_PERMISSIONS = [:view_risks, :add_risks, :edit_risks, :delete_risks, :manage_risk_relations]

  def setup
    @project = Project.find(1)
    EnabledModule.create!(:project => @project, :name => 'risks')
    @role = Role.find(1)
    @role.add_permission!(*RISK_PERMISSIONS)

    @request.session[:user_id] = 2 # jsmith, Manager on project 1
  end

  def add_journal(risk, user, attributes = {})
    journal = Journal.new({:journalized => risk, :user => user, :notes => ''}.merge(attributes))
    journal.notify = false
    journal.save!
    journal
  end

  # index

  def test_index_without_view_permission_should_be_denied
    @role.remove_permission!(:view_risks)

    compatible_request :get, :index, :project_id => 'ecookbook'

    assert_response 403
  end

  def test_index_should_list_visible_risks
    compatible_request :get, :index, :project_id => 'ecookbook', :set_filter => 1,
                       :f => ['status'], :op => {'status' => '='}, :v => {'status' => ['open', 'closed']}, :sort => 'id'

    assert_response :success
    assert_select 'table.risks tbody tr.hascontextmenu', 2
    assert_select 'tr#risk-1.risk'
    assert_select 'tr#risk-2.risk.closed'
    assert_select 'td.subject a', :text => 'Sit sodales posuere'
    assert_select 'td.subject a', :text => 'Imperdiet nibh eleifend purus'
  end

  def test_index_grouped_and_sorted_by_category
    category = RiskCategory.create!(:name => 'Technical')
    Risk.find(1).update_column(:category_id, category.id)

    compatible_request :get, :index, :project_id => 'ecookbook', :set_filter => 1,
                       :f => ['status'], :op => {'status' => '='}, :v => {'status' => ['open', 'closed']},
                       :group_by => 'category', :sort => 'category,id'

    assert_response :success
    assert_select 'tr.group', :text => /Technical/
    assert_select 'table.risks tbody tr.risk', 2
  end

  def test_index_grouped_by_risk_levels_should_display_level_labels
    {
      'probability' => ['Medium', 'Low'],
      'impact' => ['Significant', 'Moderate'],
      'magnitude' => ['Medium', 'Low'],
      'strategy' => ['Mitigate', 'Transfer']
    }.each do |group_by, labels|
      compatible_request :get, :index, :project_id => 'ecookbook', :set_filter => 1,
                         :f => ['status'], :op => {'status' => '='}, :v => {'status' => ['open', 'closed']},
                         :group_by => group_by

      assert_response :success
      assert_select 'tr.group span.name', 2
      assert_select 'tr.group span.name', :text => labels.first
      assert_select 'tr.group span.name', :text => labels.last
      assert_select 'tr.group span.badge.badge-count.count', :text => '1', :count => 2
    end
  end

  def test_index_with_invalid_query_should_render_errors
    compatible_request :get, :index, :project_id => 'ecookbook', :set_filter => 1,
                       :f => ['risk_id'], :op => {'risk_id' => '='}, :v => {'risk_id' => ['abc']}

    assert_response :success
    assert_select '#errorExplanation'
    assert_select 'table.risks', 0
  end

  # new / create

  def test_new_without_add_permission_should_be_denied
    @role.remove_permission!(:add_risks)

    compatible_request :get, :new, :project_id => 'ecookbook'

    assert_response 403
  end

  def test_new_should_display_form
    compatible_request :get, :new, :project_id => 'ecookbook'

    assert_response :success
    assert_select 'form#risk-form' do
      assert_select 'input[name=?]', 'risk[subject]'
      assert_select 'input[name=?]', 'continue'
    end
  end

  def test_create_with_invalid_attributes_should_render_new_with_errors
    assert_no_difference 'Risk.count' do
      compatible_request :post, :create, :project_id => 'ecookbook', :risk => {:subject => '', :impact => 50}
    end

    assert_response :success
    assert_select '#errorExplanation', :text => /Subject cannot be blank/
    assert_select 'form#risk-form'
  end

  def test_create_should_set_author_and_flash_notice
    assert_difference 'Risk.count' do
      compatible_request :post, :create, :project_id => 'ecookbook', :risk => {:subject => 'New risk'}
    end

    risk = Risk.order(:id).last
    assert_redirected_to "/risks/#{risk.id}"
    assert_equal User.find(2), risk.author
    assert_equal 'open', risk.status
    assert_match /successfully created/, flash[:notice]
  end

  def test_create_and_continue_should_redirect_to_new_form
    compatible_request :post, :create, :project_id => 'ecookbook', :continue => '1',
                       :risk => {:subject => 'New risk'}

    assert_redirected_to '/projects/ecookbook/risks/new'
  end

  def test_create_and_continue_should_keep_back_url
    compatible_request :post, :create, :project_id => 'ecookbook', :continue => '1', :back_url => '/projects/ecookbook/risks',
                       :risk => {:subject => 'New risk'}

    assert_redirected_to '/projects/ecookbook/risks/new?back_url=%2Fprojects%2Fecookbook%2Frisks'
  end

  def test_create_with_back_url_should_redirect_to_back_url
    compatible_request :post, :create, :project_id => 'ecookbook', :back_url => '/projects/ecookbook/risks',
                       :risk => {:subject => 'New risk'}

    assert_redirected_to '/projects/ecookbook/risks'
  end

  def test_create_in_another_project_without_permission_should_be_denied
    # The risks module is not enabled on project 2
    assert_no_difference 'Risk.count' do
      compatible_request :post, :create, :project_id => 'ecookbook', :risk => {:subject => 'New risk', :project_id => '2'}
    end

    assert_response 403
  end

  def test_create_should_not_accept_status
    compatible_request :post, :create, :project_id => 'ecookbook', :risk => {:subject => 'New risk', :status => 'closed'}

    risk = Risk.order(:id).last
    assert_equal 'New risk', risk.subject
    assert_equal 'open', risk.status
    assert_nil risk.closed_on
  end

  # show

  def test_show_without_view_permission_should_be_denied
    @role.remove_permission!(:view_risks)

    compatible_request :get, :show, :id => 1

    assert_response 403
  end

  def test_show_unknown_risk_should_respond_404
    compatible_request :get, :show, :id => 999

    assert_response 404
  end

  def test_show_should_display_risk_details_and_history
    add_journal(Risk.find(1), User.find(2), :notes => 'First risk note')
    add_journal(Risk.find(1), User.find(3), :notes => 'Second risk note')

    compatible_request :get, :show, :id => 1

    assert_response :success
    assert_select 'h2', :text => 'Risk #1'
    assert_select 'div.subject h3', :text => 'Sit sodales posuere'
    assert_select 'div.treatments .wiki', :text => /Fringilla nam in pellentesque/
    assert_select 'div.lessons', 0
    assert_select '#history .journal', 2
    assert_select '#history .journal:first-of-type .wiki', :text => 'First risk note'
    assert_select '#relations tr#relation-1'
    assert_select 'div.contextual a.icon-del'
  end

  def test_show_should_display_journals_in_reverse_order_when_preferred
    add_journal(Risk.find(1), User.find(2), :notes => 'First risk note')
    add_journal(Risk.find(1), User.find(3), :notes => 'Second risk note')
    User.find(2).pref.update!(:comments_sorting => 'desc')

    compatible_request :get, :show, :id => 1

    assert_response :success
    notes = css_select('#history .journal .wiki').map {|n| n.text.strip}
    assert_equal ['Second risk note', 'First risk note'], notes
  end

  def test_show_should_hide_private_notes_of_other_users_without_permission
    add_journal(Risk.find(1), User.find(1), :notes => 'Secret note', :private_notes => true)
    @role.remove_permission!(:view_private_notes)

    compatible_request :get, :show, :id => 1

    assert_response :success
    assert_select '#history', 0
    assert_not_include 'Secret note', response.body
  end

  def test_show_should_display_relation_changes
    risk = Risk.find(1)
    risk.init_journal(User.find(2))
    risk.issues << Issue.find(2)

    compatible_request :get, :show, :id => 1

    assert_response :success
    assert_select '#history ul.details li', :text => /Related to.*#2/
  end

  # edit / update

  def test_edit_without_edit_permission_should_be_denied
    @role.remove_permission!(:edit_risks)

    compatible_request :get, :edit, :id => 1

    assert_response 403
  end

  def test_update_without_edit_permission_should_be_denied
    @role.remove_permission!(:edit_risks)

    compatible_request :put, :update, :id => 1, :risk => {:subject => 'Changed'}

    assert_response 403
    assert_equal 'Sit sodales posuere', Risk.find(1).subject
  end

  def test_update_with_invalid_attributes_should_render_edit_with_errors
    compatible_request :put, :update, :id => 1, :risk => {:subject => '', :impact => 50}

    assert_response :success
    assert_select '#errorExplanation', :text => /Subject cannot be blank/
    assert_select 'form#risk-form'
    assert_equal 'Sit sodales posuere', Risk.find(1).subject
  end

  def test_update_with_notes_should_create_journal
    assert_difference 'Journal.count' do
      compatible_request :put, :update, :id => 1, :risk => {:subject => 'Changed', :notes => 'Some notes'}
    end

    assert_redirected_to '/risks/1'
    assert_match /successfully updated/, flash[:notice]

    journal = Journal.order(:id).last
    assert_equal 'Risk', journal.journalized_type
    assert_equal 1, journal.journalized_id
    assert_equal 'Some notes', journal.notes
    assert_equal User.find(2), journal.user
    detail = journal.details.detect {|d| d.prop_key == 'subject'}
    assert_equal 'Sit sodales posuere', detail.old_value
    assert_equal 'Changed', detail.value
  end

  def test_update_with_back_url_should_redirect_to_back_url
    compatible_request :put, :update, :id => 1, :back_url => '/projects/ecookbook/risks', :risk => {:subject => 'Changed'}

    assert_redirected_to '/projects/ecookbook/risks'
  end

  def test_update_should_change_status
    compatible_request :put, :update, :id => 1, :risk => {:status => 'rejected'}

    risk = Risk.find(1)
    assert_equal 'rejected', risk.status
    assert_not_nil risk.closed_on
  end

  def test_update_with_conflict_resolution_cancel_should_not_change_risk
    assert_no_difference 'Journal.count' do
      compatible_request :put, :update, :id => 1, :conflict_resolution => 'cancel', :risk => {:subject => 'Changed'}
    end

    assert_redirected_to '/risks/1'
    assert_equal 'Sit sodales posuere', Risk.find(1).subject
  end

  def test_update_with_conflict_resolution_add_notes_should_only_add_notes
    compatible_request :put, :update, :id => 1, :conflict_resolution => 'add_notes',
                       :risk => {:subject => 'Changed', :notes => 'Only notes'}

    assert_redirected_to '/risks/1'
    risk = Risk.find(1)
    assert_equal 'Sit sodales posuere', risk.subject
    assert_equal 'Only notes', risk.journals.last.notes
  end

  def test_update_with_conflict_resolution_overwrite_should_update_risk
    compatible_request :put, :update, :id => 1, :conflict_resolution => 'overwrite',
                       :risk => {:subject => 'Changed', :lock_version => '0'}

    assert_redirected_to '/risks/1'
    assert_equal 'Changed', Risk.find(1).subject
  end

  # destroy

  def test_destroy_without_delete_permission_should_be_denied
    @role.remove_permission!(:delete_risks)

    assert_no_difference 'Risk.count' do
      compatible_request :delete, :destroy, :id => 1
    end

    assert_response 403
  end

  def test_destroy_unknown_risk_should_respond_404
    compatible_request :delete, :destroy, :ids => [999]

    assert_response 404
  end

  def test_destroy_should_redirect_to_project_risks
    compatible_request :delete, :destroy, :ids => [1, 2]

    assert_redirected_to '/projects/ecookbook/risks'
    assert_match /successfully deleted/, flash[:notice]
    assert_equal 0, Risk.where(:id => [1, 2]).count
  end

  def test_destroy_risk_of_non_visible_project_should_be_denied
    risk = Risk.create!(:project_id => 2, :subject => 'Private', :author_id => 1)

    compatible_request :delete, :destroy, :ids => [risk.id]

    assert_response 403
    assert Risk.exists?(risk.id)
  end

  # bulk_update

  def test_bulk_update_without_edit_permission_should_be_denied
    @role.remove_permission!(:edit_risks)

    compatible_request :post, :bulk_update, :ids => [1, 2], :risk => {:impact => 100}

    assert_response 403
    assert_equal 50, Risk.find(1).impact
  end

  def test_bulk_update_with_notes_should_create_journals
    assert_difference 'Journal.count', 2 do
      compatible_request :post, :bulk_update, :ids => [1, 2], :notes => 'Bulk notes', :risk => {:strategy => 'accept'}
    end

    assert_redirected_to '/projects/ecookbook/risks'
    assert_match /successfully updated/, flash[:notice]
    assert_equal ['Bulk notes'], Journal.where(:journalized_type => 'Risk').pluck(:notes).uniq
    assert_equal ['accept'], Risk.where(:id => [1, 2]).pluck(:strategy).uniq
  end

  def test_bulk_update_with_invalid_value_should_not_set_flash_notice
    compatible_request :post, :bulk_update, :ids => [1, 2], :risk => {:impact => 500}

    assert_response :success
    assert_nil flash[:notice]
    assert_select '#errorExplanation', :text => /#1, #2/
    assert_equal [50, 75], Risk.where(:id => [1, 2]).order(:id).pluck(:impact)
  end

  def test_bulk_update_should_clear_attribute_with_none
    compatible_request :post, :bulk_update, :ids => [1], :risk => {:assigned_to_id => 'none'}

    assert_nil Risk.find(1).assigned_to_id
  end

  # bulk_edit

  def test_bulk_edit_without_edit_permission_should_be_denied
    @role.remove_permission!(:edit_risks)

    compatible_request :get, :bulk_edit, :ids => [1, 2]

    assert_response 403
  end

  def test_bulk_edit_with_edit_permission_should_display_form
    compatible_request :get, :bulk_edit, :ids => [1, 2]

    assert_response :success
    assert_select 'form#bulk_edit_form[action=?]', '/risks/bulk_update'
  end

  def test_bulk_edit_should_not_display_custom_fields_hidden_from_user_role
    visible = RiskCustomField.create!(:name => 'Visible field', :field_format => 'string', :visible => true)
    hidden = RiskCustomField.create!(:name => 'Hidden field', :field_format => 'string', :visible => false, :role_ids => [3])

    compatible_request :get, :bulk_edit, :ids => [1, 2]

    assert_response :success
    assert_select 'input[name=?]', "risk[custom_field_values][#{visible.id}]"
    assert_select 'input[name=?]', "risk[custom_field_values][#{hidden.id}]", 0
  end

  def test_bulk_update_should_ignore_custom_fields_hidden_from_user_role
    hidden = RiskCustomField.create!(:name => 'Hidden field', :field_format => 'string', :visible => false, :role_ids => [3])

    compatible_request :post, :bulk_update, :ids => [1, 2],
      :risk => {:strategy => 'accept', :custom_field_values => {hidden.id.to_s => 'Hacked'}}

    assert_redirected_to '/projects/ecookbook/risks'
    assert_equal 'accept', Risk.find(1).strategy
    assert_nil CustomValue.find_by(:custom_field_id => hidden.id, :value => 'Hacked')
  end

  def test_bulk_edit_should_be_denied_if_one_risk_is_not_editable
    EnabledModule.create!(:project_id => 2, :name => 'risks')
    Role.find(2).add_permission!(:view_risks) # jsmith is Developer on project 2
    risk = Risk.create!(:project_id => 2, :subject => 'Read-only risk', :author_id => 1)

    compatible_request :get, :bulk_edit, :ids => [1, risk.id]

    assert_response 403
  end

  def test_bulk_update_should_be_denied_if_one_risk_is_not_editable
    EnabledModule.create!(:project_id => 2, :name => 'risks')
    Role.find(2).add_permission!(:view_risks)
    risk = Risk.create!(:project_id => 2, :subject => 'Read-only risk', :author_id => 1)

    compatible_request :post, :bulk_update, :ids => [1, risk.id], :risk => {:strategy => 'accept'}

    assert_response 403
    assert_equal 'mitigate', Risk.find(1).strategy
  end

  # quoted

  def test_quoted_without_notes_permission_should_be_denied
    @role.remove_permission!(:add_issue_notes)

    compatible_xhr_request :post, :quoted, :id => 1

    assert_response 403
  end

  def test_quoted_should_replace_pre_blocks
    Risk.find(1).update_column(:description, "Line 1\r\n<pre>code</pre>\r\nLine 2")

    compatible_xhr_request :post, :quoted, :id => 1

    assert_response :success
    assert_include '> Line 1', response.body
    assert_include '> [...]', response.body
    assert_not_include 'code', response.body.scan(/> .*/).join
  end

  # preview

  def test_preview_existing_risk_without_edit_and_notes_permissions_should_be_denied
    @role.remove_permission!(:edit_risks, :add_issue_notes)

    compatible_request :post, :preview, :id => 1, :risk => {:description => 'Foo'}

    assert_response 403
  end

  def test_preview_existing_risk_with_unchanged_description_should_only_render_notes
    compatible_request :post, :preview, :id => 1,
                       :risk => {:description => "Amet tellus quis phasellus dis ultrices nulla"},
                       :journal => {:notes => 'Previewed *notes*'}

    assert_response :success
    assert_select 'fieldset.preview', 1
    assert_select 'fieldset.preview legend', :text => 'Notes'
    assert_select 'fieldset.preview', :html => /<(em|strong)>notes<\/\1>/
  end

  def test_preview_existing_risk_with_risk_notes
    compatible_request :post, :preview, :id => 1, :risk => {:notes => 'Risk _notes_'}

    assert_response :success
    assert_select 'fieldset.preview em', :text => 'notes'
  end

  def test_index_with_unknown_query_should_respond_404
    compatible_request :get, :index, :project_id => 'ecookbook', :query_id => 999

    assert_response 404
  end

  def test_edit_with_conflict_resolution_cancel_should_redirect_to_risk
    compatible_request :get, :edit, :id => 1, :conflict_resolution => 'cancel'

    assert_redirected_to '/risks/1'
  end

  def test_update_with_unknown_conflict_resolution_should_update_risk
    compatible_request :put, :update, :id => 1, :conflict_resolution => 'unknown', :risk => {:subject => 'Changed'}

    assert_redirected_to '/risks/1'
    assert_equal 'Changed', Risk.find(1).subject
  end

  # copy

  def test_show_with_add_permission_should_display_copy_link
    compatible_request :get, :show, :id => 1

    assert_response :success
    assert_select '.contextual a.icon-copy[href=?]', '/projects/ecookbook/risks/1/copy'
  end

  def test_show_without_add_permission_should_not_display_copy_link
    @role.remove_permission!(:add_risks)

    compatible_request :get, :show, :id => 1

    assert_response :success
    assert_select 'a.icon-copy', 0
  end

  def test_copy_without_add_permission_should_be_denied
    @role.remove_permission!(:add_risks)

    compatible_request :get, :new, :project_id => 'ecookbook', :copy_from => 1

    assert_response 403
  end

  def test_create_copy_without_add_permission_should_be_denied
    @role.remove_permission!(:add_risks)

    assert_no_difference 'Risk.count' do
      compatible_request :post, :create, :project_id => 'ecookbook', :copy_from => 1,
                         :risk => {:project_id => '1', :subject => 'Copy'}
    end

    assert_response 403
  end

  def test_copy_should_set_current_user_as_author
    assert_difference 'Risk.count' do
      compatible_request :post, :create, :project_id => 'ecookbook', :copy_from => 2,
                         :risk => {:project_id => '1', :subject => 'Copy'}
    end

    risk = Risk.order(:id).last
    assert_equal User.find(2), risk.author
    assert_equal 'open', risk.status
    assert_nil risk.closed_on
  end

  def test_copy_should_list_only_target_projects_with_add_permission
    EnabledModule.create!(:project => Project.find(2), :name => 'risks')

    compatible_request :get, :new, :project_id => 'ecookbook', :copy_from => 1

    assert_response :success
    assert_select 'select[name=?]', 'risk[project_id]' do
      assert_select 'option[value=?]', '1'
      assert_select 'option[value=?]', '2', 0
    end

    Role.find(2).add_permission!(:add_risks) # jsmith is Developer on project 2

    compatible_request :get, :new, :project_id => 'ecookbook', :copy_from => 1

    assert_select 'select[name=?]', 'risk[project_id]' do
      assert_select 'option[value=?]', '2'
    end
  end

  def test_create_copy_in_target_project_without_add_permission_should_be_denied
    EnabledModule.create!(:project => Project.find(2), :name => 'risks')

    assert_no_difference 'Risk.count' do
      compatible_request :post, :create, :project_id => 'ecookbook', :copy_from => 1,
                         :risk => {:project_id => '2', :subject => 'Copy'}
    end

    assert_response 403
  end

  def test_create_copy_in_target_project_with_add_permission
    EnabledModule.create!(:project => Project.find(2), :name => 'risks')
    Role.find(2).add_permission!(:add_risks)

    assert_difference 'Risk.count' do
      compatible_request :post, :create, :project_id => 'ecookbook', :copy_from => 1,
                         :risk => {:project_id => '2', :subject => 'Copy'}
    end

    assert_equal 2, Risk.order(:id).last.project_id
  end

  def test_copy_of_risk_from_non_visible_project_should_be_denied
    risk = Risk.find(1)
    risk.update_column(:project_id, 2) # risks module is not enabled on project 2

    compatible_request :get, :new, :project_id => 'ecookbook', :copy_from => risk.id

    assert_response 403
  end
end
