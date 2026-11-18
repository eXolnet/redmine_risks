require File.expand_path('../../test_helper', __FILE__)

class ActivitiesControllerTest < ActionController::TestCase
  tests ActivitiesController

  fixtures :projects, :users, :email_addresses, :roles, :members, :member_roles,
           :enabled_modules, :trackers, :projects_trackers, :issue_statuses,
           :issues, :enumerations, :journals, :journal_details, :risks, :risk_issues

  def setup
    EnabledModule.create!(:project_id => 1, :name => 'risks')
    Role.find(1).add_permission!(:view_risks)
    @request.session[:user_id] = 2 # jsmith, Manager on project 1
  end

  def add_journal(risk, attributes = {})
    journal = Journal.new({:journalized => risk, :user => User.find(2)}.merge(attributes))
    journal.notify = false
    journal.save!
    journal
  end

  def test_project_activity_should_list_risks_and_risk_notes
    Risk.find(1).update_column(:created_on, 1.hour.ago)
    journal = add_journal(Risk.find(1), :notes => 'Risk activity note')

    compatible_request :get, :index, :id => 'ecookbook', :show_risks => 1

    assert_response :success
    assert_select 'dl dt.risk a[href=?]', '/risks/1', :text => 'Risk #1: Sit sodales posuere'
    assert_select 'dl dt.risk a[href=?]', "/risks/1#change-#{journal.id}", :text => 'Risk #1: Sit sodales posuere'
    assert_select 'dl dd .description', :text => 'Risk activity note'
    assert_select 'dl dt a[href^=?]', '/issues/', 0
  end

  def test_activity_should_list_notes_of_risk_without_matching_issue
    risk = Risk.create!(:project_id => 1, :subject => 'Risk without issue', :author_id => 2)
    risk.update_column(:id, 1000)
    add_journal(Risk.find(1000), :notes => 'Note on risk 1000')

    compatible_request :get, :index, :id => 'ecookbook', :show_risks => 1

    assert_response :success
    assert_select 'dl dt a', :text => 'Risk #1000: Risk without issue', :count => 2
    assert_select 'dl dd .description', :text => 'Note on risk 1000'
  end

  def test_activity_should_list_private_risk_notes_only_with_permission
    add_journal(Risk.find(1), :notes => 'Private risk note', :private_notes => true, :user => User.find(1))

    compatible_request :get, :index, :id => 'ecookbook', :show_risks => 1

    assert_response :success
    assert_select 'dl dd .description', :text => 'Private risk note', :count => 1

    Role.find(1).remove_permission!(:view_private_notes)
    compatible_request :get, :index, :id => 'ecookbook', :show_risks => 1

    assert_response :success
    assert_select 'dl dd .description', :text => 'Private risk note', :count => 0
  end

  def test_activity_should_list_own_private_risk_notes
    Role.find(1).remove_permission!(:view_private_notes)
    add_journal(Risk.find(1), :notes => 'My private risk note', :private_notes => true)

    compatible_request :get, :index, :id => 'ecookbook', :show_risks => 1

    assert_response :success
    assert_select 'dl dd .description', :text => 'My private risk note', :count => 1
  end

  def test_activity_should_not_list_risk_notes_of_projects_without_view_risks_permission
    add_journal(Risk.find(1), :notes => 'Risk activity note')
    # jsmith can view risks of project 2 but not of project 1, where issue #1 is visible
    Role.find(1).remove_permission!(:view_risks)
    Role.find(2).add_permission!(:view_risks)
    EnabledModule.create!(:project_id => 2, :name => 'risks')

    compatible_request :get, :index, :show_risks => 1

    assert_response :success
    assert_select 'dl dd .description', :text => 'Risk activity note', :count => 0
    assert_select 'dl dt a', :text => /Sit sodales posuere/, :count => 0
  end
end
