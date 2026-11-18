require File.expand_path('../../test_helper', __FILE__)

class IssuePatchTest < ActiveSupport::TestCase
  fixtures :projects,
           :users,
           :roles,
           :members,
           :member_roles,
           :enabled_modules,
           :trackers,
           :issue_statuses,
           :enumerations,
           :issues,
           :risks,
           :risk_issues

  def setup
    EnabledModule.create(:project => Project.find(1), :name => 'risks')
  end

  def test_risks
    assert_equal [1], Issue.find(1).risks.map(&:id)
  end

  def test_visible_risks_for_allowed_user
    assert_equal [1], Issue.find(1).visible_risks(User.find(1)).map(&:id)
  end

  def test_visible_risks_without_view_risks_permission
    Role.find(1).remove_permission!(:view_risks)

    assert_equal [], Issue.find(1).visible_risks(User.find(2)).to_a
  end

  def test_visible_risks_with_module_disabled
    EnabledModule.where(:project_id => 1, :name => 'risks').delete_all

    assert_equal [], Issue.find(1).visible_risks(User.find(1)).to_a
  end
end
