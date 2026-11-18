require File.expand_path('../../test_helper', __FILE__)

class RisksIssuesControllerTest < ActionController::TestCase
  tests IssuesController

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
           :workflows,
           :risks,
           :risk_issues

  def setup
    EnabledModule.create(:project => Project.find(1), :name => 'risks')
    @request.session[:user_id] = 1
  end

  def test_show_should_display_related_risks
    compatible_request :get, :show, :id => 1

    assert_response :success
    assert_select 'head link[rel=stylesheet][href*="risks"]'
    assert_select '#issue-risks' do
      assert_select 'p strong', :text => 'Related risks'
      assert_select 'tr#issue-risk-1' do
        assert_select 'td.subject', :text => 'Risk #1: Sit sodales posuere'
        assert_select 'td.subject a[href="/risks/1"]', :text => 'Risk #1'
        assert_select 'td.status', :text => 'Open'
        assert_select 'td.strategy', :text => 'Mitigate'
        assert_select 'td.assigned_to a', :text => 'Redmine Admin'
        assert_select 'td.buttons a.icon-link-break[href="/issues/1/risks/1"]'
      end
      assert_select 'form#new-issue-risk-form[action="/issues/1/risks"]'
    end
  end

  def test_show_should_display_related_risks_stats
    Risk.find(2).issues << Issue.find(1) # closed risk

    compatible_request :get, :show, :id => 1

    assert_response :success
    assert_select '#issue-risks .issues-stat' do
      assert_select '.badge-issues-count a', :text => '2'
      assert_select '.open a', :text => '1 open'
      assert_select '.closed a', :text => '1 closed'
    end

    # The total link lists the risks related to the issue, whatever their status
    href = css_select('#issue-risks .badge-issues-count a').first['href']
    assert_include '/projects/ecookbook/risks?', href
    assert_include 'v%5Brelated_issue%5D%5B%5D=1', href
    assert_not_include 'status', href

    href = css_select('#issue-risks .issues-stat .open a').first['href']
    assert_include 'v%5Bstatus%5D%5B%5D=open', href

    href = css_select('#issue-risks .issues-stat .closed a').first['href']
    assert_include 'v%5Bstatus%5D%5B%5D=closed&v%5Bstatus%5D%5B%5D=rejected', href
  end

  def test_show_without_closed_risk_should_not_link_closed_count
    compatible_request :get, :show, :id => 1

    assert_response :success
    assert_select '#issue-risks .issues-stat .closed', :text => '0 closed'
    assert_select '#issue-risks .issues-stat .closed a', 0
  end

  def test_show_without_related_risk_should_not_display_section
    compatible_request :get, :show, :id => 2

    assert_response :success
    assert_select '#issue-risks', 0
  end

  def test_show_without_view_risks_permission_should_not_display_section
    Role.find(1).remove_permission!(:view_risks)
    @request.session[:user_id] = 2 # jsmith, manager of project 1

    compatible_request :get, :show, :id => 1

    assert_response :success
    assert_select '#issue-risks', 0
  end

  def test_show_with_risks_module_disabled_should_not_display_section
    EnabledModule.where(:project_id => 1, :name => 'risks').delete_all

    compatible_request :get, :show, :id => 1

    assert_response :success
    assert_select '#issue-risks', 0
  end

  def test_show_without_manage_permission_should_not_display_link_controls
    Role.find(1).add_permission!(:view_risks)
    Role.find(1).remove_permission!(:manage_risk_relations)
    @request.session[:user_id] = 2 # jsmith, manager of project 1

    compatible_request :get, :show, :id => 1

    assert_response :success
    assert_select '#issue-risks tr#issue-risk-1'
    assert_select '#issue-risks a.icon-link-break', 0
    assert_select '#new-issue-risk-form', 0
  end
end
