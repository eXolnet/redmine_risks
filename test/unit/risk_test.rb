require File.expand_path('../../test_helper', __FILE__)

class RiskTest < ActiveSupport::TestCase
  fixtures :projects, :users, :email_addresses, :groups_users, :roles, :members, :member_roles,
           :enabled_modules, :enumerations, :trackers, :projects_trackers, :issue_statuses,
           :issues, :journals, :journal_details, :risks, :risk_issues

  RISK_PERMISSIONS = [:view_risks, :add_risks, :edit_risks, :delete_risks, :manage_risk_relations]

  def setup
    User.current = nil
    EnabledModule.create!(:project_id => 1, :name => 'risks')
    Role.find(1).add_permission!(*RISK_PERMISSIONS)
  end

  def teardown
    User.current = nil
  end

  def add_journal(risk, user, attributes = {})
    journal = Journal.new({:journalized => risk, :user => user, :notes => ''}.merge(attributes))
    journal.notify = false
    journal.save!
    journal
  end

  def test_magnitude_calculation
    assert_equal "Low", Risk.new(:probability => 100, :impact => 0).magnitude
    assert_equal "Low", Risk.new(:probability => 100, :impact => 24).magnitude
    assert_equal "Medium", Risk.new(:probability => 100, :impact => 25).magnitude
    assert_equal "Medium", Risk.new(:probability => 100, :impact => 49).magnitude
    assert_equal "High", Risk.new(:probability => 100, :impact => 50).magnitude
    assert_equal "High", Risk.new(:probability => 100, :impact => 74).magnitude
    assert_equal "Extreme", Risk.new(:probability => 100, :impact => 75).magnitude
    assert_equal "Extreme", Risk.new(:probability => 100, :impact => 100).magnitude

    assert_equal "Low", Risk.new(:probability => 0, :impact => 100).magnitude
    assert_equal "Low", Risk.new(:probability => 24, :impact => 100).magnitude
    assert_equal "Medium", Risk.new(:probability => 25, :impact => 100).magnitude
    assert_equal "Medium", Risk.new(:probability => 49, :impact => 100).magnitude
    assert_equal "High", Risk.new(:probability => 50, :impact => 100).magnitude
    assert_equal "High", Risk.new(:probability => 74, :impact => 100).magnitude
    assert_equal "Extreme", Risk.new(:probability => 75, :impact => 100).magnitude
    assert_equal "Extreme", Risk.new(:probability => 100, :impact => 100).magnitude

    assert_equal "Low", Risk.new(:probability => 0, :impact => 0).magnitude
    assert_equal "Low", Risk.new(:probability => 25, :impact => 25).magnitude
    assert_equal "Medium", Risk.new(:probability => 50, :impact => 50).magnitude
    assert_equal "High", Risk.new(:probability => 75, :impact => 75).magnitude
    assert_equal "Extreme", Risk.new(:probability => 100, :impact => 100).magnitude
  end

  def test_magnitude_level
    assert_nil Risk.new(:probability => nil, :impact => 50).magnitude_level
    assert_nil Risk.new(:probability => 50, :impact => nil).magnitude_level
    assert_equal 0, Risk.new(:probability => 0, :impact => 0).magnitude_level
    assert_equal 0, Risk.new(:probability => 100, :impact => 24).magnitude_level
    assert_equal 1, Risk.new(:probability => 50, :impact => 50).magnitude_level
    assert_equal 2, Risk.new(:probability => 75, :impact => 75).magnitude_level
    assert_equal 3, Risk.new(:probability => 100, :impact => 75).magnitude_level
    assert_equal 3, Risk.new(:probability => 100, :impact => 100).magnitude_level
  end

  def test_assigning_closed_status_should_set_closed_on
    risk = Risk.find(1)
    risk.status = 'closed'
    risk.save!

    assert_not_nil risk.reload.closed_on
    assert risk.closed?
  end

  def test_assigning_open_status_should_clear_closed_on
    risk = Risk.find(2)
    risk.status = 'open'
    risk.save!

    assert_nil risk.reload.closed_on
    assert_not risk.closed?
  end

  def test_switching_between_closed_statuses_should_keep_closed_on
    risk = Risk.find(2)
    closed_on = risk.closed_on
    risk.status = 'rejected'
    risk.save!

    assert_equal closed_on, risk.reload.closed_on
  end

  def test_validations
    risk = Risk.new(:project_id => 1, :subject => 'Subject', :author_id => 1)
    assert risk.valid?

    risk.impact = 101
    assert_include :impact, risk.tap(&:valid?).errors.attribute_names
    risk.impact = 100
    risk.probability = -1
    assert_include :probability, risk.tap(&:valid?).errors.attribute_names
    risk.probability = 0
    risk.strategy = 'ignore'
    assert_include :strategy, risk.tap(&:valid?).errors.attribute_names
    risk.strategy = 'accept'
    risk.subject = 'a' * 256
    assert_include :subject, risk.tap(&:valid?).errors.attribute_names
    risk.subject = 'a' * 255
    assert risk.valid?
  end

  def test_new_risk_should_require_author_and_project
    risk = Risk.new(:subject => 'Subject')

    assert_not risk.valid?
    assert_include :author, risk.errors.attribute_names
    assert_include :project, risk.errors.attribute_names
  end

  def test_existing_risk_with_missing_author_should_be_valid_unless_author_changes
    risk = Risk.find(1)
    risk.update_column(:author_id, 999)

    assert risk.reload.valid?
    risk.author_id = 998
    assert_not risk.valid?
  end

  def test_magnitude_should_be_nil_without_probability_or_impact
    assert_nil Risk.new(:probability => 50).magnitude
    assert_nil Risk.new(:impact => 50).magnitude
  end

  def test_close_and_reopen_events
    risk = Risk.find(1)

    assert risk.close
    assert_equal 'closed', risk.reload.status
    assert_not_nil risk.closed_on
    assert risk.closed?
    assert_not risk.close, 'A closed risk should not be closed again'

    assert risk.reopen
    assert_equal 'open', risk.reload.status
    assert_nil risk.closed_on
    assert_not risk.reopen, 'An open risk should not be reopened'
  end

  def test_new_risk_should_be_open
    risk = Risk.new
    assert_equal 'open', risk.status
    assert_not risk.closing?
  end

  def test_new_closed_risk_should_be_closing
    risk = Risk.new(:closed_on => Time.now)
    assert risk.closing?
  end

  def test_open_scope
    assert_equal [1], Risk.open.pluck(:id)
    assert_equal [1], Risk.open(true).pluck(:id)
    assert_equal [2], Risk.open(false).pluck(:id)
  end

  def test_recently_updated_scope
    Risk.find(2).update_column(:updated_on, 1.day.from_now)

    assert_equal [2, 1], Risk.recently_updated.pluck(:id)
  end

  def test_on_active_project_scope
    assert_equal [1, 2], Risk.on_active_project.order(:id).pluck(:id)

    Project.find(1).update_column(:status, Project::STATUS_ARCHIVED)
    assert_equal [], Risk.on_active_project.pluck(:id)
  end

  def test_assigned_to_scope_with_user_should_include_risks_assigned_to_its_groups
    Risk.find(1).update_column(:assigned_to_id, 8)
    Risk.find(2).update_column(:assigned_to_id, 10) # group of user 8

    assert_equal [1, 2], Risk.assigned_to(User.find(8)).order(:id).pluck(:id)
    assert_equal [2], Risk.assigned_to(Group.find(10)).pluck(:id)
    assert_equal [1], Risk.assigned_to(8).pluck(:id)
  end

  def test_assigned_to_scope_without_principal_should_return_none
    assert_equal [], Risk.assigned_to([]).to_a
    assert_equal [], Risk.assigned_to(nil).to_a
  end

  def test_like_scope
    assert_equal [1], Risk.like('SODALES').pluck(:id)
    assert_equal [1, 2], Risk.like('').order(:id).pluck(:id)
  end

  def test_permissions_for_member
    risk = Risk.find(1)
    jsmith = User.find(2)

    assert risk.visible?(jsmith)
    assert risk.editable?(jsmith)
    assert risk.attributes_editable?(jsmith)
    assert risk.notes_addable?(jsmith)
    assert risk.deletable?(jsmith)
    assert risk.closable?(jsmith)
    assert_not Risk.find(2).closable?(jsmith), 'A closed risk should not be closable'
  end

  def test_permissions_for_non_member
    risk = Risk.find(1)
    user = User.find(4)

    assert_not risk.visible?(user)
    assert_not risk.editable?(user)
    assert_not risk.deletable?(user)
    assert_not risk.closable?(user)
  end

  def test_permissions_should_use_current_user_by_default
    User.current = User.find(2)
    risk = Risk.find(1)

    assert risk.visible?
    assert risk.editable?
    assert risk.deletable?

    User.current = User.find(4)
    assert_not risk.visible?
    assert_not risk.editable?
  end

  def test_risk_of_closed_project_should_be_read_only
    Project.find(1).update_column(:status, Project::STATUS_CLOSED)
    risk = Risk.find(1)
    jsmith = User.find(2)

    assert risk.visible?(jsmith)
    assert_not risk.editable?(jsmith)
    assert_not risk.notes_addable?(jsmith)
    assert_not risk.deletable?(jsmith)
  end

  def test_safe_attributes_on_new_risk
    risk = Risk.new
    risk.safe_attributes = {'project_id' => '1', 'subject' => 'New', 'status' => 'closed', 'private_notes' => '1'}

    assert_equal 1, risk.project_id
    assert_equal 'New', risk.subject
    assert_equal 'open', risk.status
    assert_include 'project_id', risk.safe_attribute_names(User.find(2))
    assert_not_include 'status', risk.safe_attribute_names(User.find(2))
    assert_not_include 'private_notes', risk.safe_attribute_names(User.find(2))
  end

  def test_safe_attributes_on_existing_risk
    risk = Risk.find(1)
    jsmith = User.find(2)

    names = risk.safe_attribute_names(jsmith)
    assert_include 'status', names
    assert_include 'private_notes', names
    assert_include 'notes', names
    assert_not_include 'project_id', names

    risk.init_journal(jsmith)
    risk.send(:safe_attributes=, {'status' => 'rejected', 'project_id' => '2', 'notes' => 'Note', 'private_notes' => '1'}, jsmith)
    assert_equal 'rejected', risk.status
    assert_equal 1, risk.project_id
    assert_equal 'Note', risk.notes
    assert risk.private_notes
  end

  def test_safe_attributes_without_edit_permission_should_only_allow_notes
    Role.find(1).remove_permission!(:edit_risks)
    risk = Risk.find(1)
    jsmith = User.find(2)

    assert_equal %w(notes private_notes), risk.safe_attribute_names(jsmith).sort

    risk.init_journal(jsmith)
    risk.send(:safe_attributes=, {'subject' => 'Changed', 'notes' => 'Note'}, jsmith)
    assert_equal 'Sit sodales posuere', risk.subject
    assert_equal 'Note', risk.notes
  end

  def test_safe_attributes_should_accept_parameters_and_filter_custom_fields
    risk = Risk.find(1)
    params = ActionController::Parameters.new(
      'subject' => 'Changed',
      'custom_field_values' => {'1' => 'foo'},
      'custom_fields' => [{'id' => '1', 'value' => 'foo'}]
    )

    risk.send(:safe_attributes=, params, User.find(1))
    assert_equal 'Changed', risk.subject
    assert_equal [], risk.custom_field_values

    risk.safe_attributes = 'not a hash'
    assert_equal 'Changed', risk.subject
  end

  def test_assign_attributes_with_nil_should_do_nothing
    risk = Risk.find(1)
    risk.assign_attributes(nil)
    assert_not risk.changed?
  end

  def test_attributes_should_assign_project_first
    risk = Risk.new
    risk.attributes = {:subject => 'Subject', :project => Project.find(1)}

    assert_equal 1, risk.project_id
    assert_equal 'Subject', risk.subject
  end

  def test_project_id_setter
    risk = Risk.find(1)
    risk.project_id = '1'
    assert_equal Project.find(1), risk.project

    risk.project_id = '2'
    assert_equal Project.find(2), risk.project

    risk.project_id = ''
    assert_nil risk.project
  end

  def test_description_should_normalize_line_endings
    risk = Risk.new
    risk.description = "a\nb\rc\r\nd"
    assert_equal "a\r\nb\r\nc\r\nd", risk.description

    risk.description = nil
    assert_nil risk.description
  end

  def test_category
    category = RiskCategory.create!(:name => 'Technical')
    risk = Risk.find(1)
    risk.category_id = category.id

    assert_equal category, risk.category
  end

  def test_adding_and_removing_issue_should_be_journalized
    risk = Risk.find(1)
    risk.init_journal(User.find(2))

    assert_difference 'JournalDetail.count' do
      risk.issues << Issue.find(2)
    end
    detail = JournalDetail.order(:id).last
    assert_equal ['relation', 'relates', nil, '2'], [detail.property, detail.prop_key, detail.old_value, detail.value]
    assert_equal risk, detail.journal.journalized

    assert_difference 'JournalDetail.count' do
      risk.issues.delete(Issue.find(2))
    end
    detail = JournalDetail.order(:id).last
    assert_equal ['relation', 'relates', '2', nil], [detail.property, detail.prop_key, detail.old_value, detail.value]
  end

  def test_adding_issue_without_journal_should_not_be_journalized
    risk = Risk.find(1)

    assert_no_difference 'Journal.count' do
      risk.issues << Issue.find(2)
    end
    assert_equal [1, 2], risk.issues.map(&:id).sort
  end

  def test_saving_with_journal_should_record_changes
    risk = Risk.find(1)
    risk.init_journal(User.find(2), 'Some notes')
    risk.subject = 'Changed'

    assert_difference 'Journal.count' do
      assert risk.save
    end
    journal = risk.journals.last
    assert_equal 'Some notes', journal.notes
    assert_equal risk.journals.maximum(:id), risk.last_journal_id

    risk.clear_journal
    assert_nil risk.current_journal
    assert_nil Risk.new.last_journal_id
  end

  def test_journals_after
    risk = Risk.find(1)
    j1 = add_journal(risk, User.find(2), :notes => 'One')
    j2 = add_journal(risk, User.find(2), :notes => 'Two')

    assert_equal [j1, j2], risk.journals_after(nil).to_a
    assert_equal [j2], risk.journals_after(j1.id.to_s).to_a
  end

  def test_last_updated_by_and_last_notes
    risk = Risk.find(1)
    assert_nil risk.last_updated_by
    assert_nil risk.last_notes

    add_journal(risk, User.find(2), :notes => 'Note')
    add_journal(risk, User.find(3))

    risk.reload
    assert_equal User.find(3), risk.last_updated_by
    assert_equal 'Note', risk.last_notes
  end

  def test_load_visible_last_updated_by_and_last_notes
    risks = Risk.where(:id => [1, 2]).order(:id).to_a
    add_journal(risks[0], User.find(2), :notes => 'Public note')
    add_journal(risks[0], User.find(1), :notes => 'Private note', :private_notes => true)

    Role.find(1).remove_permission!(:view_private_notes)
    Risk.load_visible_last_updated_by(risks, User.find(2))
    Risk.load_visible_last_notes(risks, User.find(2))

    assert_equal User.find(2), risks[0].last_updated_by
    assert_equal 'Public note', risks[0].last_notes
    assert_nil risks[1].last_updated_by
    assert_equal '', risks[1].last_notes

    Risk.load_visible_last_updated_by(risks, User.find(1))
    Risk.load_visible_last_notes(risks, User.find(1))
    assert_equal User.find(1), risks[0].last_updated_by
    assert_equal 'Private note', risks[0].last_notes

    # reload should clear the preloaded values
    assert_equal User.find(1), risks[0].reload.last_updated_by

    assert_nil Risk.load_visible_last_updated_by([])
    assert_nil Risk.load_visible_last_notes([])
  end

  def test_visible_journals_with_index_should_filter_private_notes
    risk = Risk.find(1)
    add_journal(risk, User.find(2), :notes => 'Public')
    add_journal(risk, User.find(1), :notes => 'Private of admin', :private_notes => true)
    add_journal(risk, User.find(3), :notes => 'Private of dlopper', :private_notes => true)
    add_journal(risk, User.find(2)) # empty journal, not displayed

    Role.find(1).remove_permission!(:view_private_notes)
    journals = risk.visible_journals_with_index(User.find(2))
    assert_equal ['Public'], journals.map(&:notes)
    assert_equal [1], journals.map(&:indice)

    journals = risk.visible_journals_with_index(User.find(3))
    assert_equal ['Public', 'Private of dlopper'], journals.map(&:notes)
    assert_equal [1, 3], journals.map(&:indice)

    journals = risk.visible_journals_with_index(User.find(1))
    assert_equal 3, journals.size
  end

  def test_css_classes
    risk = Risk.find(1)

    assert_equal 'risk', risk.css_classes(User.find(2))
    assert_equal 'risk created-by-me assigned-to-me', risk.css_classes(User.find(1))
    assert_equal 'risk closed', Risk.find(2).css_classes(User.find(2))

    risk.assigned_to_id = 10
    assert_equal 'risk assigned-to-my-group', risk.css_classes(User.find(8))
  end

  def test_assignable_users
    risk = Risk.find(1)
    risk.update_column(:assigned_to_id, 4) # not a member of project 1
    risk.reload
    risk.assigned_to_id = 2

    users = risk.assignable_users
    assert_include User.find(1), users # author
    assert_include User.find(2), users # member
    assert_include User.find(4), users # previous assignee
    assert_equal users.uniq, users
  end

  def test_assigned_to_users
    risk = Risk.find(1)
    assert_equal [User.find(1)], risk.assigned_to_users

    risk.assigned_to = Group.find(10)
    assert_equal Group.find(10).users.to_a, risk.assigned_to_users

    risk.assigned_to = nil
    assert_equal [], risk.assigned_to_users
  end

  def test_assigned_to_was
    risk = Risk.find(1)
    assert_nil risk.assigned_to_was
    assert_equal [], risk.assigned_to_was_users

    risk.assigned_to = Group.find(10)
    assert_equal User.find(1), risk.assigned_to_was
    assert_equal [User.find(1)], risk.assigned_to_was_users

    risk.save!
    assert_equal User.find(1), risk.assigned_to_was

    risk = Risk.find(1)
    risk.assigned_to_id = 2
    assert_equal Group.find(10), risk.assigned_to_was
    assert_equal Group.find(10).users.to_a, risk.assigned_to_was_users
  end

  def test_find_referenced_issue_by_id
    risk = Risk.find(1)

    assert_nil risk.find_referenced_issue_by_id('')
    assert_nil risk.find_referenced_issue_by_id(nil)
    assert_equal Issue.find(2), risk.find_referenced_issue_by_id('2')
  end

  def test_event_attributes
    assert_equal 'Risk #1: Sit sodales posuere', Risk.find(1).event_title
    assert_equal 'risk', Risk.find(1).event_type
    assert_equal 'risk-closed', Risk.find(2).event_type
    assert_equal({:controller => 'risks', :action => 'show', :id => 1}, Risk.find(1).event_url.except(:host, :port, :protocol, :script_name))
  end

  def test_destroy_should_destroy_journals
    risk = Risk.find(1)
    add_journal(risk, User.find(2), :notes => 'Note')

    assert_difference 'Journal.count', -1 do
      risk.destroy
    end
  end

  def test_issue_journal_events_should_not_be_changed
    journal = Journal.find(1) # issue journal

    assert_equal 'issue-edit', journal.event_type
    assert_match /\ABug #1/, journal.event_title
    assert_equal Issue.find(1), journal.event_group
    assert_equal 'issues', journal.event_url[:controller]
  end

  def test_risk_journal_events
    journal = add_journal(Risk.find(1), User.find(2), :notes => 'Note')

    assert_equal 'risk', journal.event_type
    assert_equal 'Risk #1: Sit sodales posuere', journal.event_title
    assert_equal Risk.find(1), journal.event_group
    assert_equal({:controller => 'risks', :action => 'show', :id => 1, :anchor => "change-#{journal.id}", :only_path => true},
                 journal.event_url(:only_path => true))
  end

  def test_assignable_users_should_not_include_locked_author
    risk = Risk.find(1)
    risk.author = User.find(5) # locked user

    assert_not_include User.find(5), risk.assignable_users
  end

  def test_saving_unchanged_risk_should_not_change_updated_on
    risk = Risk.find(1)
    updated_on = risk.updated_on

    assert risk.save
    assert_equal updated_on, risk.reload.updated_on
  end


  def test_required_custom_field_should_be_validated
    field = RiskCustomField.create!(:name => 'Mandatory', :field_format => 'string', :is_required => true)
    risk = Risk.new(:project_id => 1, :author_id => 1, :subject => 'Risk with custom field')

    assert_not risk.save
    assert_include "Mandatory #{::I18n.t('activerecord.errors.messages.blank')}", risk.errors.full_messages

    risk.custom_field_values = {field.id.to_s => 'Value'}
    assert risk.save
    assert_equal 'Value', risk.reload.custom_field_value(field)
  end

  def test_safe_attributes_should_ignore_custom_fields_not_visible_by_the_user
    Role.find(2).add_permission!(*RISK_PERMISSIONS)
    public_field = RiskCustomField.create!(:name => 'Public', :field_format => 'string')
    private_field = RiskCustomField.create!(:name => 'Managers only', :field_format => 'string', :visible => false, :role_ids => [1])
    risk = Risk.find(1)

    risk.send :safe_attributes=, {'custom_field_values' => {public_field.id.to_s => 'A', private_field.id.to_s => 'B'}}, User.find(3)
    assert_equal 'A', risk.custom_field_value(public_field)
    assert_nil risk.custom_field_value(private_field)
    assert_equal [public_field], risk.visible_custom_field_values(User.find(3)).map(&:custom_field)

    risk.send :safe_attributes=, {'custom_fields' => [{'id' => private_field.id, 'value' => 'B'}]}, User.find(2)
    assert_equal 'B', risk.custom_field_value(private_field)
  end

  def test_custom_field_changes_should_be_journalized
    field = RiskCustomField.create!(:name => 'Owner team', :field_format => 'string')
    risk = Risk.find(1)

    risk.init_journal(User.find(1))
    risk.custom_field_values = {field.id.to_s => 'Ops'}
    assert risk.save

    journal = risk.journals.order(:id).last
    detail = journal.details.detect {|d| d.property == 'cf'}
    assert_not_nil detail
    assert_equal field.id.to_s, detail.prop_key
    assert_nil detail.old_value
    assert_equal 'Ops', detail.value
  end

  def test_journal_custom_field_details_should_respect_visibility
    field = RiskCustomField.create!(:name => 'Managers only', :field_format => 'string', :visible => false, :role_ids => [1])
    risk = Risk.find(1)
    risk.init_journal(User.find(1))
    risk.custom_field_values = {field.id.to_s => 'Secret'}
    assert risk.save
    journal = risk.journals.order(:id).last

    assert_equal 1, journal.visible_details(User.find(2)).size
    assert_equal 0, journal.visible_details(User.find(3)).size
  end

  def test_destroy_should_delete_custom_values
    field = RiskCustomField.create!(:name => 'Owner team', :field_format => 'string')
    risk = Risk.find(1)
    risk.custom_field_values = {field.id.to_s => 'Ops'}
    assert risk.save

    assert_difference 'CustomValue.where(:customized_type => "Risk").count', -1 do
      risk.destroy
    end
  end
end
